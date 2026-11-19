"""core.py — 구형 부표 회피 알고리즘 (ROS 의존 없음)
─────────────────────────────────────────────────────────────────────────────
노드(buoy_detector_node / buoy_planner_node)와 오프라인 평가 스크립트(tools/)가
같은 코드를 쓰도록 순수 numpy/scipy/opencv 로만 작성한다.

좌표계: LiDAR 프레임(livox_frame) = 바디 프레임으로 본다. x 전방, y 왼쪽, z 위.
    (exp1016 bag 에서 라이다 x 축이 선수 방향과 일치함을 확인)

처리 흐름:
    1. extract_buoy_clusters  — ROI 크롭 → 2D(xy) 유클리드 클러스터링 → 구형 부표 크기/높이 필터
    2. FisheyeCamera.project  — 클러스터 중심을 어안 카메라 이미지로 투영 (cv2.fisheye 모델)
    3. classify_clusters      — 투영 위치의 작은 원형 패치만 색 판정 → red / green / unknown
                                (기본 adaptive: Lab 색상각 + 프레임 내 상대 채도. hsv: 고정 HSV 범위)
    4. BuoyTracker            — 프레임 간 연결 + 색 투표 누적 (카메라 시야 밖 옆쪽 부표도 색 유지)
    5. GatePlanner            — red-green 쌍 → 게이트 중점 → 목표점 → 안전거리 보정 → 헤딩/속도
─────────────────────────────────────────────────────────────────────────────
"""
import math

import cv2
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

RED = 'red'
GREEN = 'green'
UNKNOWN = 'unknown'

# 라이다(x 전방, y 왼쪽, z 위) → 카메라 광학 프레임(x 오른쪽, y 아래, z 전방) 축 교환
R_LIDAR_TO_OPTICAL_BASE = np.array([[0.0, -1.0, 0.0],
                                    [0.0, 0.0, -1.0],
                                    [1.0, 0.0, 0.0]])


# ─── 1. LiDAR 클러스터링 ──────────────────────────────────────────────────────

def euclidean_cluster_2d(xy, tolerance):
    """xy 평면 유클리드 클러스터링 (PCL EuclideanClusterExtraction 과 같은 연결 성분 방식).

    구형 부표는 위아래로 길지 않아서 z 를 빼고 묶어야, 먼 거리에서 스캔 라인 간격이
    벌어져 한 부표가 위/아래 조각으로 갈라지는 것을 막을 수 있다.
    """
    n = len(xy)
    if n == 0:
        return np.zeros(0, dtype=int), 0
    pairs = cKDTree(xy).query_pairs(tolerance, output_type='ndarray')
    graph = coo_matrix((np.ones(len(pairs)), (pairs[:, 0], pairs[:, 1])), shape=(n, n))
    n_comp, labels = connected_components(graph, directed=False)
    return labels, n_comp


def extract_buoy_clusters(points, p):
    """점군(N x >=3, x/y/z[/intensity]) → 부표 후보 배열 (M x 7).

    열: x, y, z, n_points, xy_extent, z_min, z_max
    x, y 는 보이는 반구 표면 점들의 중심을 레이 방향으로 center_push_m 만큼 밀어
    구 중심에 가깝게 보정한 값이고, z 는 (z_min + z_max) / 2 다.
    """
    pts = np.asarray(points, dtype=np.float32)
    if pts.size == 0:
        return np.zeros((0, 7))
    pts = pts[np.abs(pts[:, :3]).sum(axis=1) > 1e-3]          # Livox 무반사 (0,0,0) 제거
    r = np.hypot(pts[:, 0], pts[:, 1])
    m = ((r > p['min_range_m']) & (r < p['max_range_m'])
         & (pts[:, 2] > p['z_min_m']) & (pts[:, 2] < p['z_max_m'])
         & (pts[:, 0] > p['x_min_m']))
    pts = pts[m]
    labels, n = euclidean_cluster_2d(pts[:, :2], p['cluster_tolerance_m'])

    out = []
    for c in range(n):
        q = pts[labels == c]
        if len(q) < p['cluster_min_points']:
            continue
        extent = float(np.ptp(q[:, :2], axis=0).max())
        z_lo, z_hi = float(q[:, 2].min()), float(q[:, 2].max())
        if not (p['buoy_min_extent_m'] <= extent <= p['buoy_max_extent_m']):
            continue
        # 부표는 수면 근처에서 시작해 사람 키보다 낮다 — 벽/나무/말뚝 윗부분 제거
        if z_hi > p['buoy_top_max_z_m'] or z_lo > p['buoy_bottom_max_z_m'] or z_hi < p['buoy_top_min_z_m']:
            continue
        cx, cy = q[:, :2].mean(axis=0)
        rng = math.hypot(cx, cy)
        if rng > 1e-3:
            cx += p['center_push_m'] * cx / rng
            cy += p['center_push_m'] * cy / rng
        out.append((cx, cy, 0.5 * (z_lo + z_hi), len(q), extent, z_lo, z_hi))
    return np.array(out, dtype=float).reshape(-1, 7)


# ─── 2. 어안 카메라 투영 ──────────────────────────────────────────────────────

class FisheyeCamera:
    """cv2.fisheye(Kannala-Brandt) 모델 + 라이다→카메라 외부 파라미터.

    rvec_correction: 축 교환(R_LIDAR_TO_OPTICAL_BASE) 뒤에 광학 프레임에서 추가로 곱하는
                     작은 회전 (Rodrigues, rad). 장착 틸트/요 오차 보정분.
    tvec:            광학 프레임에서 본 라이다 원점 위치 [m] (cv2 projectPoints 의 tvec 와 동일 의미).
    """

    def __init__(self, fx, fy, cx, cy, dist, rvec_correction, tvec, width, height, valid_radius_px):
        self.K = np.array([[fx, 0.0, cx], [0.0, fy, cy], [0.0, 0.0, 1.0]])
        self.D = np.asarray(dist, dtype=np.float64).reshape(4)
        R = cv2.Rodrigues(np.asarray(rvec_correction, dtype=np.float64))[0] @ R_LIDAR_TO_OPTICAL_BASE
        self.R = R
        self.rvec = cv2.Rodrigues(R)[0]
        self.tvec = np.asarray(tvec, dtype=np.float64).reshape(3)
        self.width = int(width)
        self.height = int(height)
        self.valid_radius_px = float(valid_radius_px)
        self.f_mean = 0.5 * (fx + fy)

    @classmethod
    def from_params(cls, p):
        return cls(p['fx'], p['fy'], p['cx'], p['cy'], p['dist'], p['rvec_correction'],
                   p['tvec'], p['width'], p['height'], p['valid_radius_px'])

    def to_camera(self, P):
        return (self.R @ np.asarray(P, dtype=np.float64).reshape(-1, 3).T).T + self.tvec

    def project(self, P):
        """(N,3) 라이다 점 → (N,2) 픽셀, (N,) 유효 마스크 (카메라 앞 + 이미지 원 안)."""
        # clusters[:, :3] 같은 비연속 슬라이스를 그대로 넘기면 cv2 가 메모리를 잘못 읽는다
        P = np.ascontiguousarray(np.asarray(P, dtype=np.float64).reshape(-1, 3))
        if len(P) == 0:
            return np.zeros((0, 2)), np.zeros(0, dtype=bool)
        uv, _ = cv2.fisheye.projectPoints(P.reshape(-1, 1, 3), self.rvec, self.tvec, self.K, self.D)
        uv = uv.reshape(-1, 2)
        Pc = self.to_camera(P)
        # 어안이라 z<0(측후방)도 수식상 투영은 되지만, 광축과 100° 이상 벌어지면 렌즈 밖으로 본다
        ang = np.arctan2(np.hypot(Pc[:, 0], Pc[:, 1]), Pc[:, 2])
        c = self.K[:2, 2]
        valid = ((ang < math.radians(100.0))
                 & (np.linalg.norm(uv - c, axis=1) < self.valid_radius_px)
                 & (uv[:, 0] >= 0) & (uv[:, 0] < self.width)
                 & (uv[:, 1] >= 0) & (uv[:, 1] < self.height))
        return uv, valid

    def pixel_radius(self, P, radius_m):
        """구 반지름 radius_m 이 이미지에서 차지하는 대략적인 픽셀 반지름 (등거리 근사)."""
        d = np.linalg.norm(self.to_camera(P), axis=1)
        return self.f_mean * np.arcsin(np.clip(radius_m / np.maximum(d, radius_m + 1e-3), 0.0, 1.0))


# ─── 3. 색 판정 ───────────────────────────────────────────────────────────────

def color_masks(hsv, p):
    """HSV 이미지 → {'red': mask, 'green': mask}. 빨강은 H 가 0/179 양쪽에 걸쳐 범위가 두 개."""
    red = np.zeros(hsv.shape[:2], np.uint8)
    for lo, hi in p['red_hsv_ranges']:
        red |= cv2.inRange(hsv, tuple(lo), tuple(hi))
    green = np.zeros(hsv.shape[:2], np.uint8)
    for lo, hi in p['green_hsv_ranges']:
        green |= cv2.inRange(hsv, tuple(lo), tuple(hi))
    return {RED: red, GREEN: green}


def classify_patch(masks, u, v, r_px, p):
    """(u, v) 중심, 반지름 r_px 원형 패치 안의 red/green 픽셀 비율로 색을 정한다.

    반환: (label, red_frac, green_frac)
    """
    h, w = masks[RED].shape
    r = int(max(p['patch_min_radius_px'], min(p['patch_max_radius_px'], r_px * p['patch_radius_scale'])))
    x0, x1 = max(0, int(u) - r), min(w, int(u) + r + 1)
    y0, y1 = max(0, int(v) - r), min(h, int(v) + r + 1)
    if x1 <= x0 or y1 <= y0:
        return UNKNOWN, 0.0, 0.0
    yy, xx = np.mgrid[y0:y1, x0:x1]
    disk = (xx - u) ** 2 + (yy - v) ** 2 <= r * r
    n = int(disk.sum())
    if n == 0:
        return UNKNOWN, 0.0, 0.0
    fr = float((masks[RED][y0:y1, x0:x1][disk] > 0).sum()) / n
    fg = float((masks[GREEN][y0:y1, x0:x1][disk] > 0).sum()) / n
    thr = p['min_color_fraction']
    if fr >= thr and fr >= p['color_dominance'] * fg:
        return RED, fr, fg
    if fg >= thr and fg >= p['color_dominance'] * fr:
        return GREEN, fr, fg
    return UNKNOWN, fr, fg


def _disk(shape, u, v, r_px, p):
    """(u, v) 중심 원형 패치의 (슬라이스, 마스크). 패치 반지름은 부표 반지름 × patch_radius_scale."""
    h, w = shape
    r = int(max(p['patch_min_radius_px'], min(p['patch_max_radius_px'], r_px * p['patch_radius_scale'])))
    x0, x1 = max(0, int(u) - r), min(w, int(u) + r + 1)
    y0, y1 = max(0, int(v) - r), min(h, int(v) + r + 1)
    if x1 <= x0 or y1 <= y0:
        return None, None
    yy, xx = np.mgrid[y0:y1, x0:x1]
    disk = (xx - u) ** 2 + (yy - v) ** 2 <= r * r
    if not disk.any():
        return None, None
    return (slice(y0, y1), slice(x0, x1)), disk


def patch_chroma(ab, u, v, r_px, p):
    """패치에서 채도 상위 절반 픽셀의 Lab (a, b) 중앙값 → (색상각 deg, 채도).

    상위 절반만 쓰는 이유: 패치에 섞인 물/하늘(무채색)과 반사광을 빼고 부표 몸통 색만 보려고.
    """
    sl, disk = _disk(ab.shape[:2], u, v, r_px, p)
    if sl is None:
        return 0.0, 0.0
    px = ab[sl][disk]
    c = np.hypot(px[:, 0], px[:, 1])
    top = px[c >= np.median(c)]
    a, b = float(np.median(top[:, 0])), float(np.median(top[:, 1]))
    return math.degrees(math.atan2(b, a)), math.hypot(a, b)


def _in_hue(deg, lo, hi):
    return lo <= deg <= hi


def classify_clusters(bgr, clusters, camera, p):
    """클러스터마다 (label, u, v, r_px, red_score, green_score) 리스트를 돌려준다.

    color_mode:
      adaptive (기본, 2026-11-02~) — 고정 임계값 대신 이번 프레임에 보이는 색으로 판정한다.
          1) 패치의 색상각(Lab a-b 평면)이 red_hue_deg / green_hue_deg 구간이면 그 색 후보.
             그림자/역광에서 S·V 는 크게 떨어져도 색상각은 거의 그대로다
             (11-02 16:36 bag 역광: 초록 H≈60 S≈45, 빨강 H≈172 S≈84 → 고정 HSV 하한에 걸려 전부 unknown).
          2) 후보의 채도가 max(color_min_chroma, color_relative_chroma × 이번 프레임 같은 색 후보 최대 채도)
             이상이면 그 색. 밝은 장면에선 문턱이 올라가 채도 낮은 나무 말뚝/원거리 잡색을 거르고,
             어두운 장면에선 내려가 그늘진 부표를 살린다.
          score 칸에는 채도를 넣는다.
      hsv — 고정 HSV 범위 안 픽셀 비율 (red_hsv_ranges / green_hsv_ranges, min_color_fraction).
    이미지가 없거나 투영이 유효하지 않으면 label=unknown.
    """
    n = len(clusters)
    res = [(UNKNOWN, -1.0, -1.0, 0.0, 0.0, 0.0)] * n
    if bgr is None or n == 0:
        return res
    P = clusters[:, :3]
    uv, valid = camera.project(P)
    rpx = camera.pixel_radius(P, p['buoy_radius_m'])

    if p.get('color_mode', 'adaptive') == 'hsv':
        masks = color_masks(cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV), p)
        for i in range(n):
            if not valid[i]:
                continue
            lab, fr, fg = classify_patch(masks, uv[i, 0], uv[i, 1], rpx[i], p)
            res[i] = (lab, float(uv[i, 0]), float(uv[i, 1]), float(rpx[i]), fr, fg)
        return res

    ab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)[:, :, 1:].astype(np.float32) - 128.0
    cand = []                                   # (i, color, chroma)
    for i in range(n):
        if not valid[i]:
            continue
        hue, chroma = patch_chroma(ab, uv[i, 0], uv[i, 1], rpx[i], p)
        if _in_hue(hue, *p['red_hue_deg']):
            cand.append((i, RED, chroma))
        elif _in_hue(hue, *p['green_hue_deg']):
            cand.append((i, GREEN, chroma))
        else:
            cand.append((i, UNKNOWN, chroma))
    cmax = {col: max([c for _, cc, c in cand if cc == col], default=0.0) for col in (RED, GREEN)}
    for i, col, chroma in cand:
        lab = UNKNOWN
        if col != UNKNOWN and chroma >= max(p['color_min_chroma'], p['color_relative_chroma'] * cmax[col]):
            lab = col
        res[i] = (lab, float(uv[i, 0]), float(uv[i, 1]), float(rpx[i]),
                  chroma if col == RED else 0.0, chroma if col == GREEN else 0.0)
    return res


# ─── 4. 트래커 ────────────────────────────────────────────────────────────────

class Track:
    __slots__ = ('id', 'x', 'y', 'votes', 'hits', 'last_seen', 'first_seen')

    def __init__(self, tid, x, y, t):
        self.id = tid
        self.x = x
        self.y = y
        self.votes = {RED: 0.0, GREEN: 0.0}
        self.hits = 1
        self.last_seen = t
        self.first_seen = t

    def color(self, min_votes, dominance):
        r, g = self.votes[RED], self.votes[GREEN]
        if r >= min_votes and r >= dominance * g:
            return RED
        if g >= min_votes and g >= dominance * r:
            return GREEN
        return UNKNOWN


class BuoyTracker:
    """바디 프레임 단기 트래커 (오도메트리 없이 최근접 연결).

    10Hz 라이다 기준 프레임 사이 이동량이 작아서(1 m/s 직진 → 0.1 m) 최근접 연결로 충분하다.
    핵심 목적은 색 투표 누적: 부표가 배 옆으로 지나가 카메라 시야/해상도 밖으로 나가도
    앞에서 본 색을 유지해 게이트 쌍을 계속 만들 수 있게 한다.
    """

    def __init__(self, p):
        self.p = p
        self.tracks = []
        self.next_id = 0

    def update(self, clusters, labels, t):
        p = self.p
        for tr in self.tracks:
            tr.votes[RED] *= p['vote_decay']
            tr.votes[GREEN] *= p['vote_decay']
        dets = [(float(c[0]), float(c[1]), lab) for c, lab in zip(clusters, labels)]
        unmatched = list(range(len(dets)))
        if self.tracks and dets:
            T = np.array([[tr.x, tr.y] for tr in self.tracks])
            Dp = np.array([[d[0], d[1]] for d in dets])
            dist = np.linalg.norm(T[:, None, :] - Dp[None, :, :], axis=2)
            used_t, used_d = set(), set()
            for flat in np.argsort(dist, axis=None):
                i, j = np.unravel_index(flat, dist.shape)
                if dist[i, j] > p['assoc_distance_m']:
                    break
                if i in used_t or j in used_d:
                    continue
                used_t.add(i)
                used_d.add(j)
                tr = self.tracks[i]
                a = p['position_alpha']
                tr.x = (1 - a) * tr.x + a * dets[j][0]
                tr.y = (1 - a) * tr.y + a * dets[j][1]
                tr.hits += 1
                tr.last_seen = t
                if dets[j][2] in (RED, GREEN):
                    tr.votes[dets[j][2]] += 1.0
            unmatched = [j for j in range(len(dets)) if j not in used_d]
        for j in unmatched:
            tr = Track(self.next_id, dets[j][0], dets[j][1], t)
            self.next_id += 1
            if dets[j][2] in (RED, GREEN):
                tr.votes[dets[j][2]] += 1.0
            self.tracks.append(tr)
        self.tracks = [tr for tr in self.tracks if t - tr.last_seen <= p['track_timeout_sec']]

    def confirmed(self):
        """[(id, x, y, color, hits)] — min_hits 이상 연결되고 이번 주기에 살아있는 트랙."""
        p = self.p
        return [(tr.id, tr.x, tr.y, tr.color(p['min_color_votes'], p['color_dominance']), tr.hits)
                for tr in self.tracks if tr.hits >= p['min_hits']]


# ─── 5. 게이트 플래너 ─────────────────────────────────────────────────────────

def _segment_clearance(tx, ty, bx, by):
    """원점→(tx,ty) 선분과 점 (bx,by) 사이 최단거리."""
    L2 = tx * tx + ty * ty
    if L2 < 1e-9:
        return math.hypot(bx, by)
    s = max(0.0, min(1.0, (bx * tx + by * ty) / L2))
    return math.hypot(bx - s * tx, by - s * ty)


def find_gates(buoys, p, red_left):
    """buoys: [(x, y, color)] → 게이트 리스트 [(mx, my, red_xy, green_xy, width)] (가까운 순).

    red/green 상호 최근접 쌍 중 폭이 [gate_min_width_m, gate_max_width_m] 인 것만 쓴다.
    red_left 가 None 이 아니면 좌우 배치(red 가 왼쪽=+y 인지)가 맞는 쌍만 인정한다.
    """
    reds = [(b[0], b[1]) for b in buoys if b[2] == RED and b[0] > p['gate_min_x_m'] and b[0] < p['max_plan_range_m']]
    greens = [(b[0], b[1]) for b in buoys if b[2] == GREEN and b[0] > p['gate_min_x_m'] and b[0] < p['max_plan_range_m']]
    if not reds or not greens:
        return []
    R = np.array(reds)
    G = np.array(greens)
    d = np.linalg.norm(R[:, None, :] - G[None, :, :], axis=2)
    gates = []
    for i in range(len(R)):
        j = int(np.argmin(d[i]))
        if int(np.argmin(d[:, j])) != i:
            continue
        w = float(d[i, j])
        if not (p['gate_min_width_m'] <= w <= p['gate_max_width_m']):
            continue
        if red_left is not None and ((R[i, 1] > G[j, 1]) != red_left):
            continue
        mx, my = 0.5 * (R[i] + G[j])
        gates.append((float(mx), float(my), tuple(R[i]), tuple(G[j]), w))
    gates.sort(key=lambda g: math.hypot(g[0], g[1]))
    return gates


class GatePlanner:
    """게이트 중점을 따라가는 목표점 선택 + 헤딩 평활.

    목표점 선택 순서:
      1) 게이트 쌍이 있으면: 거리 lookahead_m 이상인 가장 가까운 게이트 중점
         (없으면 가장 먼 게이트 중점)
      2) 쌍이 없고 한쪽 색 줄만 보이면: 그 줄의 가장 가까운 전방 부표에서 수로 안쪽으로
         gate_nominal_width_m / 2 만큼 옮긴 점 (red_side 를 알아야 함)
      3) 아무것도 없으면: 직전 헤딩을 hold_sec 동안 유지하고 그 뒤로는 정지
    그다음 원점→목표 선분이 어떤 부표(색 무관)와도 safety_radius_m 이내로 지나가면
    목표를 좌우로 조금씩 옮겨 가장 작은 이동으로 여유가 생기는 점을 고른다.

    후보 제한 (2026-11-02, 실차에서 마지막 게이트를 지난 뒤 WP 쪽으로 꺾다가 지나온 게이트로
    되돌아간 문제):
      - 전방 콘: 게이트 중점 / 한쪽 줄 부표의 방위각이 ±max_candidate_bearing_deg 안인 것만 쓴다.
      - 통과 기억 (pose 가 주어질 때만): 게이트를 NED 로 기억하다가 배가 red-green 선분을
        넘어가면 '통과'로 표시하고, passed_gate_memory_sec 동안 그 게이트의 부표
        (passed_buoy_radius_m 이내)는 게이트/한쪽 줄 후보에서 뺀다.
      - 진행 방향 일관성: 새 게이트를 지나는 방향이 직전 통과 방향과 gate_max_turn_deg 보다
        크게 다르면 버린다 (옆 줄을 가로지르는 엉뚱한 쌍, 되돌아가는 쌍).
    안전거리 보정(_apply_clearance)은 통과한 부표도 포함한 전체 부표로 한다.
    gate_visible 은 위 제한을 통과한 게이트만 센다.
    """

    def __init__(self, p):
        self.p = p
        # 통과 판정 대기 중인 게이트 [dict(r, g, side, t)] 와 통과한 게이트 [dict(r, g, dir, t)] (NED)
        self.pending = []
        self.passed = []
        self.heading = 0.0
        self.last_target_t = None
        self.last_heading_t = None
        side = str(p['red_side']).lower()
        self.fixed_red_left = {'left': True, 'right': False}.get(side, None)
        # auto 모드: 가장 최근에 게이트 쌍을 본 프레임의 좌우 배치를 기억한다.
        # (왕복 주행으로 진행 방향이 바뀌면 red 의 좌우도 바뀌므로 누적 다수결은 늦게 따라온다)
        self.seen_red_left = None
        self.seen_red_left_t = None

    def red_left(self, t):
        if self.fixed_red_left is not None:
            return self.fixed_red_left
        if self.seen_red_left_t is None or t - self.seen_red_left_t > self.p['side_memory_sec']:
            return None
        return self.seen_red_left

    def _update_side(self, gates_any, t):
        if self.fixed_red_left is not None or not gates_any:
            return
        votes = sum(1 if g[2][1] > g[3][1] else -1 for g in gates_any)
        if votes != 0:
            self.seen_red_left = votes > 0
            self.seen_red_left_t = t

    def plan(self, buoys, t, pose=None):
        """buoys: [(x, y, color)] 바디 프레임. pose: (north, east, yaw_ned) 또는 None.

        pose 가 없으면 통과 기억/방향 검사는 건너뛰고 전방 콘 제한만 적용한다.
        반환 dict(speed, bearing, gate_visible, target, gates, mode, red_left, n_passed).
        """
        p = self.p
        all_buoys = buoys
        if pose is not None:
            self._forget(t)
            self._update_passing(pose, t)
            buoys = [b for b in buoys if not self._is_passed_buoy(b, pose)]
        cone = math.radians(p['max_candidate_bearing_deg'])
        # auto 모드: 좌우 제약 없이 쌍을 찾고, 이번 프레임 쌍들의 배치로 red_side 를 갱신한다.
        # 고정 모드(left/right): 배치가 맞는 쌍만 인정한다.
        gates = find_gates(buoys, p, self.fixed_red_left)
        gates = [g for g in gates if abs(math.atan2(g[1], g[0])) <= cone]
        if pose is not None:
            gates = [g for g in gates if self._direction_ok(g, pose)]
            self._remember(gates, pose, t)
        self._update_side(gates, t)
        red_left = self.red_left(t)

        target = None
        mode = 'none'
        if gates:
            far = [g for g in gates if math.hypot(g[0], g[1]) >= p['lookahead_m']]
            g = far[0] if far else gates[-1]
            target = (g[0], g[1])
            mode = 'gate'
        elif red_left is not None:
            # 한쪽 줄만 보임: 수로 안쪽으로 반 폭 이동
            ahead = sorted([b for b in buoys if b[2] in (RED, GREEN)
                            and b[0] > p['gate_min_x_m'] and b[0] < p['max_plan_range_m']
                            and abs(math.atan2(b[1], b[0])) <= cone],
                           key=lambda b: math.hypot(b[0], b[1]))
            far = [b for b in ahead if math.hypot(b[0], b[1]) >= p['lookahead_m']]
            pick = far[0] if far else (ahead[-1] if ahead else None)
            if pick is not None:
                # red 가 왼쪽이면 red 줄에서는 오른쪽(-y)으로, green 줄에서는 왼쪽(+y)으로 옮긴다
                toward_right = (pick[2] == RED) == red_left
                off = -0.5 * p['gate_nominal_width_m'] if toward_right else 0.5 * p['gate_nominal_width_m']
                target = (pick[0], pick[1] + off)
                mode = 'single_row'

        if target is not None:
            target = self._apply_clearance(target, all_buoys)
            desired = math.atan2(target[1], target[0])
            lim = math.radians(p['max_bearing_deg'])
            desired = max(-lim, min(lim, desired))
            self._smooth_heading(desired, t)
            self.last_target_t = t
            speed = self._speed()
        else:
            if self.last_target_t is not None and t - self.last_target_t <= p['hold_sec']:
                mode = 'hold'
                speed = self._speed()
            else:
                mode = 'stop'
                speed = 0.0
            self.last_heading_t = t

        return dict(speed=speed, bearing=self.heading, gate_visible=bool(gates),
                    target=target, gates=gates, mode=mode, red_left=red_left,
                    n_passed=len(self.passed))

    # ── 통과 기억 (NED) ──────────────────────────────────────────────────────

    @staticmethod
    def _to_ned(x, y, pose):
        """바디(x 전방, y 왼쪽) → NED (north, east). yaw_ned 는 북에서 시계방향."""
        n0, e0, yaw = pose
        c, s = math.cos(yaw), math.sin(yaw)
        return (n0 + x * c + y * s, e0 + x * s - y * c)

    @staticmethod
    def _side(r, g, pt):
        """red→green 선분 기준 pt 가 어느 쪽인지 (외적 부호)."""
        return (g[0] - r[0]) * (pt[1] - r[1]) - (g[1] - r[1]) * (pt[0] - r[0])

    def _forget(self, t):
        mem = self.p['passed_gate_memory_sec']
        self.passed = [q for q in self.passed if t - q['t'] <= mem]
        self.pending = [q for q in self.pending if t - q['t'] <= self.p['pending_gate_timeout_sec']]

    def _is_passed_buoy(self, b, pose):
        if not self.passed:
            return False
        bn, be = self._to_ned(b[0], b[1], pose)
        rad = self.p['passed_buoy_radius_m']
        for q in self.passed:
            for k in ('r', 'g'):
                if math.hypot(bn - q[k][0], be - q[k][1]) <= rad:
                    return True
        return False

    def _gate_normal_ned(self, g, pose):
        """게이트 선분의 법선 중 배에서 멀어지는 쪽(=지나갈 방향) 을 NED 각도로."""
        rx, ry = g[2]
        gx, gy = g[3]
        nx, ny = -(gy - ry), gx - rx
        if nx * g[0] + ny * g[1] < 0:
            nx, ny = -nx, -ny
        yaw = pose[2]
        c, s = math.cos(yaw), math.sin(yaw)
        return math.atan2(nx * s - ny * c, nx * c + ny * s)

    def _direction_ok(self, g, pose):
        if not self.passed:
            return True
        diff = self._gate_normal_ned(g, pose) - self.passed[-1]['dir']
        d = math.atan2(math.sin(diff), math.cos(diff))
        return abs(d) <= math.radians(self.p['gate_max_turn_deg'])

    def _remember(self, gates, pose, t):
        """이번 프레임 게이트를 대기 목록에 넣거나 갱신 (중점 거리로 같은 게이트 판단)."""
        here = (pose[0], pose[1])
        for g in gates:
            r = self._to_ned(g[2][0], g[2][1], pose)
            gr = self._to_ned(g[3][0], g[3][1], pose)
            mid = (0.5 * (r[0] + gr[0]), 0.5 * (r[1] + gr[1]))
            match = None
            for q in self.pending:
                qm = (0.5 * (q['r'][0] + q['g'][0]), 0.5 * (q['r'][1] + q['g'][1]))
                if math.hypot(mid[0] - qm[0], mid[1] - qm[1]) <= self.p['passed_buoy_radius_m']:
                    match = q
                    break
            if match is None:
                side = self._side(r, gr, here)
                if side != 0.0:
                    self.pending.append(dict(r=r, g=gr, side=side > 0, t=t))
            else:
                # 가까워질수록 위치가 정확해지므로 최신 값으로 덮어쓴다 (어느 쪽인지는 처음 본 값 유지)
                match['r'], match['g'], match['t'] = r, gr, t

    def _update_passing(self, pose, t):
        """대기 게이트 중 배가 선분(양끝 pass_margin 연장)을 넘어간 것을 통과로 옮긴다."""
        here = (pose[0], pose[1])
        margin = self.p['gate_pass_margin_m']
        keep = []
        for q in self.pending:
            r, g = q['r'], q['g']
            side = self._side(r, g, here) > 0
            if side == q['side']:
                keep.append(q)
                continue
            dx, dy = g[0] - r[0], g[1] - r[1]
            L = math.hypot(dx, dy)
            along = ((here[0] - r[0]) * dx + (here[1] - r[1]) * dy) / max(L, 1e-6)
            if -margin <= along <= L + margin:
                # 지나간 방향 = 처음 있던 쪽에서 반대쪽으로 가는 법선
                nx, ny = -dy, dx
                if q['side']:
                    nx, ny = -nx, -ny
                self.passed.append(dict(r=r, g=g, dir=math.atan2(ny, nx), t=t))
            # 선분 밖으로 넘어간 건 (옆으로 지나침) 통과로 보지 않고 대기에서 뺀다
        self.pending = keep

    def _apply_clearance(self, target, buoys):
        p = self.p
        tx, ty = target
        obstacles = [(b[0], b[1]) for b in buoys if b[0] > -0.5]
        if not obstacles:
            return target

        def clear(x, y):
            return min(_segment_clearance(x, y, bx, by) for bx, by in obstacles)

        if clear(tx, ty) >= p['safety_radius_m']:
            return target
        step = p['clearance_step_m']
        k = 1
        while k * step <= p['clearance_max_shift_m'] + 1e-9:
            for s in (k * step, -k * step):
                # 목표를 원점→목표 방향의 수직으로 이동
                L = math.hypot(tx, ty)
                nx, ny = -ty / L, tx / L
                cx, cy = tx + s * nx, ty + s * ny
                if clear(cx, cy) >= p['safety_radius_m']:
                    return (cx, cy)
            k += 1
        return target

    def _smooth_heading(self, desired, t):
        p = self.p
        a = p['heading_smooth_alpha']
        new = (1 - a) * self.heading + a * desired
        if self.last_heading_t is not None:
            dt = max(1e-3, t - self.last_heading_t)
            lim = math.radians(p['max_heading_rate_deg_s']) * dt
            new = self.heading + max(-lim, min(lim, new - self.heading))
        self.heading = new
        self.last_heading_t = t

    def _speed(self):
        p = self.p
        ratio = 1.0 - p['curvature_speed_gain'] * abs(self.heading) / (math.pi / 2)
        return p['default_speed'] * max(p['min_speed_ratio'], ratio)


# ─── 기본 파라미터 ─────────────────────────────────────────────────────────────
# config/buoy_params.yaml 과 같은 값. 노드는 yaml/launch 에서 덮어쓴다.

DEFAULT_CLUSTER_PARAMS = dict(
    min_range_m=1.0,            # 선체/라이다 자체 반사 제거
    max_range_m=20.0,
    x_min_m=-3.0,               # 배 옆을 막 지나간 부표까지는 유지 (안전거리 검사용)
    z_min_m=-1.0,
    z_max_m=1.3,
    cluster_tolerance_m=0.45,   # 부표 간격(~1.5 m 이상)보다 충분히 작게
    cluster_min_points=4,
    buoy_min_extent_m=0.05,
    buoy_max_extent_m=1.3,      # 실측 부표 xy 폭 중앙값 0.81 m (근거리)
    buoy_top_max_z_m=1.15,      # 실측 z_max 중앙값 0.67 m
    buoy_top_min_z_m=-0.1,
    buoy_bottom_max_z_m=0.3,    # 실측 z_min 중앙값 -0.39 m
    center_push_m=0.15,         # 표면 중심 → 구 중심 보정
)

DEFAULT_COLOR_PARAMS = dict(
    color_mode='adaptive',      # adaptive / hsv (classify_clusters 참고)
    # adaptive: OpenCV 8-bit Lab 의 (a-128, b-128) 평면 색상각 [deg] 과 채도
    red_hue_deg=[-40.0, 45.0],    # 11-02 bag: 빨강 부표 4~33° (역광 4~8°), 나무 말뚝 8~32° (채도로 거름)
    green_hue_deg=[100.0, 170.0],  # 초록 부표 133~144°, 물/하늘은 -90° 부근
    color_min_chroma=7.0,         # 절대 하한. 역광 초록 부표 10~11, 물 4~5
    color_relative_chroma=0.4,    # 프레임 내 같은 색 후보 최대 채도 대비 비율
    # hsv: OpenCV HSV: H 0~179. exp1016 실측 기준 (역광에서 초록이 어두워져 V 하한을 낮게 둠)
    red_hsv_ranges=[[[0, 90, 60], [9, 255, 255]], [[166, 90, 60], [179, 255, 255]]],
    green_hsv_ranges=[[[38, 60, 35], [88, 255, 255]]],
    buoy_radius_m=0.4,
    patch_radius_scale=0.6,
    patch_min_radius_px=2,
    patch_max_radius_px=40,
    min_color_fraction=0.2,
    color_dominance=2.0,
)

DEFAULT_TRACKER_PARAMS = dict(
    assoc_distance_m=0.7,
    position_alpha=0.6,
    track_timeout_sec=0.6,
    min_hits=2,
    vote_decay=0.97,
    min_color_votes=1.5,
    color_dominance=2.0,
)

DEFAULT_PLANNER_PARAMS = dict(
    red_side='auto',            # auto / left / right  (진행 방향 기준 red 가 어느 쪽인지)
    side_memory_sec=5.0,        # auto: 마지막 게이트 쌍의 좌우 배치를 이 시간 동안 기억 (한쪽 줄 모드에 사용)
    gate_min_width_m=1.5,       # 게이트 폭 2.5 m 기준 (exp1016 수조는 6.0~6.5 m)
    gate_max_width_m=8.0,
    gate_nominal_width_m=2.5,
    gate_min_x_m=0.5,
    max_plan_range_m=15.0,
    lookahead_m=3.0,
    safety_radius_m=1.0,
    clearance_step_m=0.25,
    clearance_max_shift_m=2.0,
    max_bearing_deg=60.0,
    heading_smooth_alpha=0.35,
    max_heading_rate_deg_s=60.0,
    default_speed=0.8,
    curvature_speed_gain=0.6,
    min_speed_ratio=0.3,
    hold_sec=1.0,
    # 후보 제한 (GatePlanner docstring 참고, 2026-11-02~)
    max_candidate_bearing_deg=45.0,   # 게이트 중점/한쪽 줄 부표는 전방 ±이 각도 안만 후보
    passed_gate_memory_sec=60.0,      # 통과한 게이트를 후보에서 빼는 시간
    passed_buoy_radius_m=1.5,         # NED 에서 이 거리 안의 부표는 통과한 게이트의 부표로 봄 (헤딩 오차 여유)
    pending_gate_timeout_sec=10.0,    # 본 게이트를 통과 판정 대기 목록에 두는 시간 (마지막으로 본 뒤)
    gate_pass_margin_m=1.0,           # 통과 판정 시 red-green 선분 양끝 연장 거리
    gate_max_turn_deg=90.0,           # 직전 통과 방향과 이보다 크게 다른 방향의 게이트는 버림
)
