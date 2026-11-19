#!/usr/bin/env python3
"""
bay_core.py — y-bin 기반 3-bay '베이 안쪽' 검출 (옆벽 불필요 · 대각선 대응)
────────────────────────────────────────────────────────────────────────
실측(rosbag)으로 확정된 구조:
  · 가까운 면(x 작음) = 칸막이 기둥 앞면
  · 먼 면(x 큼)      = 베이 안쪽(뒷벽)   ← 이 좌표를 publish
  · 요철 깊이 ~0.4m, 베이 주기 ~0.8m, 전방 5~8m

검출 아이디어 (LiDAR 시점 = 원점):
  1. 점군을 y축 방향으로 얇은 bin 으로 나눔
  2. 각 bin 의 대표 거리(전방 x 의 중앙값)를 구해 '거리 프로파일' 생성
  3. 프로파일에서 '멀리 들어간 구간(베이 안쪽)'을 찾음
     - 가까운 기둥면 대비 depth_min 이상 뒤로 들어간 연속 구간
  4. 각 베이 안쪽 구간의 중심 → idx(목표), 법선 → psi, 앞으로 뺀 점 → wp

이 방식은 옆벽 점이 없어도 되고, 스테이션이 기울어져(대각선) 있어도
각 y 위치의 거리만 보므로 그대로 동작한다.
좌표계: ENU (x=전방, y=좌측). 입력 points 는 (N,2) [x,y].
"""
from __future__ import annotations
import numpy as np


# ═══════════════════════════════════════════════════════════════════════
# 점 축적 (UGV 정지 전제) — PC2/LaserScan 공용
# ═══════════════════════════════════════════════════════════════════════

def voxel_downsample(points: np.ndarray, voxel: float) -> np.ndarray:
    """XY 복셀 격자당 대표 1점만 남겨 중복/과밀 제거 (N,2)→(M,2)."""
    if voxel <= 0.0 or len(points) <= 1:
        return points
    cells = np.floor(points / voxel).astype(np.int64)
    _, idx = np.unique(cells, axis=0, return_index=True)
    return points[np.sort(idx)]


class PointAccumulator:
    """UGV 정지 중 여러 프레임의 (N,2) 점을 누적해 밀도를 높인다.
    목표 점 수 도달 시 고정(freeze) 후 더 쌓지 않는다."""
    def __init__(self, voxel: float, target_pts: int):
        self.voxel = voxel
        self.target_pts = target_pts
        self._pts = np.empty((0, 2))
        self.ready = False
        self._frozen = None

    def add(self, frame_pts: np.ndarray) -> None:
        if self.ready:
            return
        if len(frame_pts):
            self._pts = np.vstack([self._pts, frame_pts])
            self._pts = voxel_downsample(self._pts, self.voxel)
        if len(self._pts) >= self.target_pts:
            self._frozen = self._pts.copy()
            self.ready = True

    def get(self) -> np.ndarray:
        return self._frozen if self.ready else self._pts

    def count(self) -> int:
        return len(self._pts)

    def reset(self) -> None:
        self._pts = np.empty((0, 2))
        self.ready = False
        self._frozen = None


def _robust_x(xs: np.ndarray) -> float:
    """bin 내 전방거리 대표값. 이상치에 강한 하위 백분위(가장 가까운 면 위주)."""
    return float(np.percentile(xs, 20))


def robust_pillar_baseline(xs: np.ndarray, anchor_band: float = 0.15) -> float:
    """
    기둥면 기준선 — '가장 가까운 bin 무리'에 앵커.

    (구) 하위 25백분위 방식의 문제: 기둥 bin 은 전체의 ~25%뿐이라(좁은 기둥
    4개 vs 넓은 베이 3개) 스테이션 비율이 조금만 달라져도 백분위가 베이
    안쪽 값으로 미끄러진다 → 분류가 반전되어 베이가 기둥 위치(반주기
    오프셋)에 잡히는 치명적 오류.

    (신) 벽밴드 필터가 스테이션 앞 잡음을 이미 제거했으므로, 남은 프로파일
    에서 가장 가까운 면은 반드시 기둥이다. 강건 최솟값(하위 5%) 근방
    anchor_band 이내 bin 들의 중앙값을 기준선으로 쓴다 — 기둥 bin 이
    몇 개뿐이어도 흔들리지 않는다.
    """
    x_near = float(np.percentile(xs, 5))
    near = xs <= x_near + anchor_band
    return float(np.median(xs[near]))


def build_profile(points: np.ndarray, y_min: float, y_max: float,
                  bin_w: float, min_pts_per_bin: int):
    """
    y 구간을 bin_w 로 나눠 각 bin 의 (y중심, 대표x, 점수) 프로파일 생성.
    반환: ys(M,), xs(M,), ns(M,)  — 점이 부족한 bin 은 제외.
    """
    edges = np.arange(y_min, y_max + bin_w, bin_w)
    ys, xs, ns = [], [], []
    for i in range(len(edges) - 1):
        m = (points[:, 1] >= edges[i]) & (points[:, 1] < edges[i + 1])
        n = int(m.sum())
        if n >= min_pts_per_bin:
            ys.append((edges[i] + edges[i + 1]) / 2.0)
            xs.append(_robust_x(points[m, 0]))
            ns.append(n)
    return np.array(ys), np.array(xs), np.array(ns)


def find_bays(points: np.ndarray, y_min: float, y_max: float,
              bin_w: float, min_pts_per_bin: int,
              depth_min: float, bay_width_min: float, bay_width_max: float,
              approach_dist: float):
    """
    베이 안쪽(멀리 들어간 구간)을 찾아 목표점 리스트 반환.

    파라미터(실측 후 조정):
      bin_w            : y 방향 bin 폭 [m] (예: 0.1)
      min_pts_per_bin  : bin 유효 최소 점 수
      depth_min        : 기둥면 대비 이만큼 뒤로 들어가야 '베이 안쪽' [m] (예: 0.25)
      bay_width_min/max: 베이 안쪽 구간의 y 폭 허용 범위 [m]
      approach_dist    : wp 를 idx 앞(원점 쪽)으로 뺄 거리 [m]

    반환(각 베이): {'idx','wp','psi','y_center','x_depth','width'}
    좌→우(y 큰 순) 정렬.
    """
    ys, xs, ns = build_profile(points, y_min, y_max, bin_w, min_pts_per_bin)
    if len(ys) < 3:
        return [], (ys, xs)

    # 기준 '기둥면' 거리 = 가장 가까운 bin 무리에 앵커 (백분위 미끄러짐 방지)
    pillar_x = robust_pillar_baseline(np.asarray(xs))
    # 베이 안쪽 = 기둥면보다 depth_min 이상 먼 bin
    is_inner = xs > (pillar_x + depth_min)

    # 연속된 inner 구간을 그룹핑
    bays = []
    i = 0
    M = len(ys)
    while i < M:
        if not is_inner[i]:
            i += 1
            continue
        j = i
        while j < M and is_inner[j]:
            j += 1
        # 구간 [i, j)
        seg_y = ys[i:j]
        seg_x = xs[i:j]
        width = abs(seg_y[-1] - seg_y[0]) + bin_w  # bin 폭 보정
        if bay_width_min <= width <= bay_width_max:
            y_c = float(np.mean(seg_y))
            x_d = float(np.median(seg_x))          # 베이 안쪽 깊이(뒷벽 거리)
            idx = np.array([x_d, y_c])
            # psi: 베이 안쪽을 향하는 진입 방향(+x 우세). 국소 기울기 반영.
            if len(seg_y) >= 2:
                # 뒷벽 선의 기울기(dy/dx)로 법선 추정
                A = np.polyfit(seg_y, seg_x, 1)      # x = A[0]*y + A[1]
                wall_dir = np.array([A[0], 1.0]); wall_dir /= np.linalg.norm(wall_dir)
                normal = np.array([-wall_dir[1], wall_dir[0]])
                if normal[0] < 0:
                    normal = -normal
            else:
                normal = np.array([1.0, 0.0])
            psi = float(np.arctan2(normal[1], normal[0]))
            wp = idx - approach_dist * normal
            bays.append({'idx': idx, 'wp': wp, 'psi': psi,
                         'y_center': y_c, 'x_depth': x_d, 'width': width})
        i = j

    bays.sort(key=lambda b: b['y_center'], reverse=True)  # 좌(y+)→우
    return bays, (ys, xs)


# ═══════════════════════════════════════════════════════════════════════
# 벽-프레임 정렬 (rectification) — 대각선 접근 대응
# ═══════════════════════════════════════════════════════════════════════

def rectify(points: np.ndarray):
    """
    점군의 지배 방향(스테이션 전면이 뻗는 방향)을 PCA 로 찾아,
    벽 방향이 y축과 평행이 되도록 점군을 회전한다.

    반환: (회전된 점군, 중심 c, 회전각 theta)
      원좌표 복원: p_orig = R(-theta) · (p_rect - c) + c
      각도 복원  : psi_orig = psi_rect - theta

    UGV 가 스테이션을 대각선에서 봐도, 이 정렬 후에는 y-bin 이 항상
    벽과 평행하게 잘려 요철 프로파일이 뭉개지지 않는다.
    정면(기울기 0)일 때는 theta≈0 이라 기존 동작과 동일하다.
    """
    c = points.mean(0)
    d = points - c
    cov = d.T @ d
    w, V = np.linalg.eigh(cov)
    wall_dir = V[:, np.argmax(w)]                     # 최대 분산 = 벽 방향
    theta = float(np.arctan2(wall_dir[0], wall_dir[1]))  # 벽방향→y축 회전각
    R = np.array([[np.cos(theta), -np.sin(theta)],
                  [np.sin(theta),  np.cos(theta)]])
    return d @ R.T + c, c, theta


def find_bays_pillars(points: np.ndarray, y_min: float, y_max: float,
                      bin_w: float, min_pts_per_bin: int,
                      depth_min: float, bay_width_min: float, bay_width_max: float,
                      approach_dist: float,
                      pillar_tol: float = 0.18, pillar_width_min: float = 0.08,
                      bridge_bins: int = 1):
    """
    기둥 기반(구조 매칭) 베이 검출 — '전방 기둥 4개 + 그 사이 3개 간격' 구조를
    직접 찾는다. (정렬된 프레임 전용: find_bays_auto 내부에서 호출)

    로직:
      1) 프로파일에서 기둥면 기준거리(하위 25%) 산출
      2) 기준거리 ±pillar_tol 안의 bin = '기둥 bin' → 연속 구간으로 그룹핑
         (bridge_bins 개까지의 구멍은 이어붙임, 폭 pillar_width_min 미만 버림)
      3) 인접 기둥 세그먼트 사이의 '간격'이 베이 폭 조건을 만족하면 베이
      4) 간격 안에 깊은 점(기준+depth_min 이상)이 있으면 실측 깊이 사용,
         없으면(가림/희소) 다른 베이의 실측 깊이 중앙값으로 **추론** —
         베이 안쪽 점이 부분적으로 비어도 양옆 기둥만 있으면 베이가 잡힌다.

    프로파일 방식(find_bays) 대비 장점: 베이 안쪽이 아니라 기둥(가장 잘
    찍히는 면)이 검출의 주체라서, 안쪽 점 소실·국소 오염에 강건하다.
    """
    ys, xs, ns = build_profile(points, y_min, y_max, bin_w, min_pts_per_bin)
    if len(ys) < 3:
        return [], (ys, xs)
    ys = np.asarray(ys); xs = np.asarray(xs)

    pillar_x = robust_pillar_baseline(xs)
    is_pillar = np.abs(xs - pillar_x) <= pillar_tol
    is_deep = xs >= (pillar_x + depth_min)

    # ── 기둥 bin → 세그먼트 그룹핑 (y 격자 인덱스 기준, 작은 구멍 이어붙임)
    gidx = np.round(ys / bin_w).astype(np.int64)
    p_idx = gidx[is_pillar]
    p_y = ys[is_pillar]
    if len(p_idx) == 0:
        return [], (ys, xs)
    order = np.argsort(p_idx)
    p_idx = p_idx[order]; p_y = p_y[order]
    segs = []          # (y_lo, y_hi)
    s = 0
    for k in range(1, len(p_idx) + 1):
        if k == len(p_idx) or p_idx[k] - p_idx[k - 1] > 1 + bridge_bins:
            y_lo = float(p_y[s]) - bin_w / 2
            y_hi = float(p_y[k - 1]) + bin_w / 2
            if (y_hi - y_lo) >= pillar_width_min:
                segs.append((y_lo, y_hi))
            s = k
    if len(segs) < 2:
        return [], (ys, xs)
    segs.sort(key=lambda t: t[0])              # y 오름차순

    # ── 인접 기둥 사이 간격 → 베이 후보
    raw = []
    for (lo1, hi1), (lo2, hi2) in zip(segs[:-1], segs[1:]):
        gap_lo, gap_hi = hi1, lo2              # 간격 y 범위
        width = gap_hi - gap_lo
        if not (bay_width_min - bin_w <= width <= bay_width_max + bin_w):
            continue
        m = (ys > gap_lo) & (ys < gap_hi) & is_deep
        if m.sum() >= 1:
            x_d = float(np.median(xs[m])); measured = True
            seg_y, seg_x = ys[m], xs[m]
        else:
            x_d = None; measured = False       # 안쪽 점 없음 → 나중에 추론
            seg_y = seg_x = None
        raw.append({'y_c': (gap_lo + gap_hi) / 2, 'width': width,
                    'x_d': x_d, 'measured': measured,
                    'seg_y': seg_y, 'seg_x': seg_x})
    if not raw:
        return [], (ys, xs)

    # ── 미실측 베이 깊이 추론 (실측 베이들의 중앙값, 없으면 depth_min×1.5)
    meas = [r['x_d'] for r in raw if r['measured']]
    fill = float(np.median(meas)) if meas else pillar_x + depth_min * 1.5
    bays = []
    for r in raw:
        x_d = r['x_d'] if r['measured'] else fill
        idx = np.array([x_d, r['y_c']])
        if r['measured'] and len(r['seg_y']) >= 2:
            A = np.polyfit(r['seg_y'], r['seg_x'], 1)
            wall_dir = np.array([A[0], 1.0]); wall_dir /= np.linalg.norm(wall_dir)
            normal = np.array([-wall_dir[1], wall_dir[0]])
            if normal[0] < 0:
                normal = -normal
        else:
            normal = np.array([1.0, 0.0])      # 정렬 프레임의 벽 법선 = +x
        psi = float(np.arctan2(normal[1], normal[0]))
        bays.append({'idx': idx, 'wp': idx - approach_dist * normal, 'psi': psi,
                     'y_center': float(r['y_c']), 'x_depth': float(x_d),
                     'width': float(r['width']), 'inferred': not r['measured']})
    bays.sort(key=lambda b: b['y_center'], reverse=True)   # 좌→우
    return bays, (ys, xs)


def wall_band_filter(rp: np.ndarray, bin_w: float,
                     band_depth: float = 0.7, x_step: float = 0.05,
                     front_margin: float = 0.05):
    """
    벽 밴드 필터 — 스테이션 앞쪽 지면/잡동사니 덩어리 제거.

    정렬된(rectified) 점군에서 '깊이 band_depth 슬랩 [x0, x0+band_depth]'를
    x 방향으로 슬라이딩하며, 그 슬랩이 덮는 **서로 다른 y-bin 수(커버리지)**가
    최대인 위치를 벽으로 선택한다.

    원리: 스테이션은 폭넓은 y 범위(≈3m)에 걸친 얕은 슬랩(기둥면~베이안쪽
    ≈0.4m)이라 커버리지가 크고, 지면 덩어리는 국소적이라 커버리지가 작다.
    점 개수가 아니라 y 커버리지로 점수를 매기므로, 지면 덩어리가 점이
    아무리 많아도 이기지 못한다. (동률이면 점수가 많은 쪽)

    반환: 밴드 내 점 마스크 (bool, len == len(rp)). 실패 시 전체 True.
    """
    if len(rp) < 10:
        return np.ones(len(rp), dtype=bool)
    x = rp[:, 0]
    ybin = np.floor(rp[:, 1] / bin_w).astype(np.int64)
    x_lo, x_hi = float(x.min()), float(x.max())
    if x_hi - x_lo <= band_depth:          # 이미 얕은 점군 → 필터 불필요
        return np.ones(len(rp), dtype=bool)

    best_score = (-1, -1); best_x0 = x_lo
    x0 = x_lo
    while x0 <= x_hi - band_depth + 1e-9:
        m = (x >= x0) & (x < x0 + band_depth)
        cov = len(np.unique(ybin[m]))       # 커버리지 = 유니크 y-bin 수
        score = (cov, int(m.sum()))
        if score > best_score:
            best_score = score; best_x0 = x0
        x0 += x_step
    return (x >= best_x0 - front_margin) & (x < best_x0 + band_depth)


def find_bays_auto(points: np.ndarray,
                   bin_w: float, min_pts_per_bin: int,
                   depth_min: float, bay_width_min: float, bay_width_max: float,
                   approach_dist: float,
                   wall_band: bool = True, band_depth: float = 0.7,
                   method: str = 'pillar'):
    """
    정렬(rectify) → 벽밴드 필터(앞쪽 지면 제거) → 재정렬 → 베이 검출
    → 결과를 원좌표계로 역변환.

    method:
      'pillar'  (권장) 기둥 4개를 직접 찾고 그 사이 간격을 베이로 판정.
                베이 안쪽 점이 비어도 양옆 기둥에서 추론. 기둥이 2개 미만으로
                안 잡히면 자동으로 profile 방식으로 폴백.
      'profile' 기존 방식: '멀리 들어간 연속 구간' = 베이.
    """
    if len(points) < min_pts_per_bin * 3:
        return [], (np.array([]), np.array([]))

    # 1차 정렬 (지면 덩어리 포함 상태 — 근사)
    rp, c, theta = rectify(points)

    if wall_band:
        keep = wall_band_filter(rp, bin_w, band_depth)
        if keep.sum() >= min_pts_per_bin * 3:
            points = points[keep]
        # 2차 정렬: 정제된 점만으로 PCA → 덩어리로 오염됐던 방향 복구
        rp, c, theta = rectify(points)

    y_lo = float(rp[:, 1].min()) - bin_w
    y_hi = float(rp[:, 1].max()) + bin_w

    bays = []; prof = (np.array([]), np.array([]))
    if method == 'pillar':
        bays, prof = find_bays_pillars(rp, y_lo, y_hi, bin_w, min_pts_per_bin,
                                       depth_min, bay_width_min, bay_width_max,
                                       approach_dist)
    if not bays:   # pillar 실패(기둥<2 등) 또는 method='profile' → 기존 방식
        bays, prof = find_bays(rp, y_lo, y_hi, bin_w, min_pts_per_bin,
                               depth_min, bay_width_min, bay_width_max,
                               approach_dist)
    # 원좌표계 복원
    Rinv = np.array([[np.cos(-theta), -np.sin(-theta)],
                     [np.sin(-theta),  np.cos(-theta)]])
    for b in bays:
        b['idx'] = (b['idx'] - c) @ Rinv.T + c
        b['wp']  = (b['wp']  - c) @ Rinv.T + c
        b['psi'] = float(b['psi'] - theta)
    return bays, prof


# ═══════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    # 실측 프로파일 흉내: 기둥 x≈4.97, 베이 안쪽 x≈5.39, 주기 0.8
    pts = []
    ycur = -1.2
    rng = np.random.default_rng(0)
    layout = [('pillar', 0.4), ('bay', 0.6)] * 3
    for kind, w in layout:
        xv = 4.97 if kind == 'pillar' else 5.39
        n = int(w / 0.02)
        for k in range(n):
            y = ycur + k * 0.02
            for _ in range(8):  # 면당 여러 점
                pts.append([xv + rng.normal(0, 0.01), y + rng.normal(0, 0.005)])
        ycur += w
    P = np.array(pts)
    bays, (ys, xs) = find_bays(P, -1.5, 2.0, bin_w=0.1, min_pts_per_bin=3,
                               depth_min=0.25, bay_width_min=0.3, bay_width_max=1.0,
                               approach_dist=0.8)
    print("프로파일 (y: x):")
    for y, x in zip(ys, xs):
        bar = '█' * int((x - 4.8) / 0.02)
        print(f"  {y:+.2f}: {x:.2f} {bar}")
    print(f"\n검출된 베이 {len(bays)}개:")
    for i, b in enumerate(bays):
        print(f"  [{i}] idx=({b['idx'][0]:.2f},{b['idx'][1]:+.2f}) "
              f"wp=({b['wp'][0]:.2f},{b['wp'][1]:+.2f}) "
              f"psi={np.degrees(b['psi']):.0f} width={b['width']:.2f}")