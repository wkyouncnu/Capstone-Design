#!/usr/bin/env python3
"""
collision_avoidance_node_livox.py — ROS 2 arc-based collision avoidance for USV
─────────────────────────────────────────────────────────────────────────────
기존 collision_avoidance_node.py와 동일한 제어 로직 / 출력 토픽을 유지하되,
LaserScan(/lidar/scan) 대신 Livox 원시 포인트클라우드(/livox/lidar)를
직접 구독하여 장애물을 식별합니다. (pointcloud_to_laserscan 노드 불필요)

토픽 구독
  /usv/state/position_ned  geometry_msgs/Point   NED (x=N, y=E)
  /usv/state/heading       std_msgs/Float32      NED 방위각 [rad, CW]
  /usv/state/goal_ned      geometry_msgs/Point   NED 목표  ← 선택
  /livox/lidar             sensor_msgs/PointCloud2  원시 3D 포인트클라우드

토픽 발행
  /vfh/command        geometry_msgs/Twist      linear.x=속도, angular.z=절대 NED 방위각
  /vfh/oa_flag        std_msgs/Bool            회피 중이면 True
  /vfh/debug_markers  visualization_msgs/MarkerArray
                        ns='arcs'      : 빨강=충돌 / 초록=안전 / 파랑굵음=선택
                        ns='obstacles' : 필터된 장애물 (노랑)
                        ns='status'    : 모드·속도·거리 텍스트
─────────────────────────────────────────────────────────────────────────────
"""
from __future__ import annotations
import math
import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from geometry_msgs.msg import Point, Twist
from sensor_msgs.msg import PointCloud2
from std_msgs.msg import Bool, Float32
from px4_msgs.msg import OperationMode
from visualization_msgs.msg import Marker, MarkerArray


# ═══════════════════════════════════════════════════════════════════════════════
#  수학 / 계획 (순수 함수) — 기존과 동일
# ═══════════════════════════════════════════════════════════════════════════════

def pi2pi(a: float) -> float:
    """각도를 (−π, π] 로 정규화."""
    return (a + math.pi) % (2.0 * math.pi) - math.pi


def compensate_ego(obs: np.ndarray, pos0: np.ndarray, h0: float,
                   pos1: np.ndarray, h1: float) -> np.ndarray:
    """
    장애물을 '클라우드가 찍힌 시점의 바디프레임' → '현재 바디프레임' 으로 옮긴다.
    obs: (N,2) 바디 ENU (x=전방, y=좌측).  h: NED 방위각(CW 양수).

    보정이 없으면 배가 움직인 만큼 장애물이 어긋난 채로 아크를 평가하게 된다.
    실비행 로그(260716, 4 bag, 1268 사이클) 실측: 4 m 앞 장애물 기준
    평균 0.10 m, 95% 0.33 m, 최대 0.75 m 어긋남 (안전반경 0.50 m).
    NED 왕복 변환과 대조해 5000 케이스 최대오차 1.2e-14 로 검산함.
    """
    if len(obs) == 0:
        return obs
    dpsi = pi2pi(h1 - h0)
    c, sn = math.cos(dpsi), math.sin(dpsi)
    d = pos1 - pos0                                   # NED 변위
    ch1, sh1 = math.cos(h1), math.sin(h1)
    tx = d[0] * ch1 + d[1] * sh1                      # 변위를 '현재 전방' 에 투영
    ty = d[0] * sh1 - d[1] * ch1                      # ... '현재 좌측' 에 투영
    return np.stack([obs[:, 0] * c - obs[:, 1] * sn - tx,
                     obs[:, 0] * sn + obs[:, 1] * c - ty], axis=-1)


def ned_yaw(heading: float, rate_enu: float) -> float:
    """ENU 요각 오프셋 → 절대 NED 방위각 (ENU CCW = NED 음방향). 호출부는 rate×T 를 넘김."""
    return pi2pi(heading - rate_enu)


# ═══════════════════════════════════════════════════════════════════════════════
#  PointCloud2 → 2D 장애물 변환 (핵심 변경 부분)
# ═══════════════════════════════════════════════════════════════════════════════

def _parse_pc2_xyz(msg: PointCloud2) -> np.ndarray:
    """
    sensor_msgs/PointCloud2 → (N, 3) float32 배열 (x, y, z).
    field 오프셋·데이터타입을 직접 읽어 파싱하므로 외부 패키지 의존 없음.
    Livox ROS2 Driver 출력(x,y,z,intensity,tag,line,timestamp 혼합 dtype)에 안전.
    point_step 단위로 x/y/z 오프셋만 읽으므로 intensity/tag/line/timestamp 는 건너뜀.
    """
    FLOAT32 = 7  # sensor_msgs/PointField.FLOAT32

    # x/y/z field 의 offset·datatype 수집
    info = {}
    for field in msg.fields:
        if field.name in ('x', 'y', 'z'):
            info[field.name] = (field.offset, field.datatype)

    if not all(k in info for k in ('x', 'y', 'z')):
        return np.empty((0, 3), dtype=np.float32)

    # Livox 는 x/y/z 가 항상 FLOAT32. 다른 타입이면 잘못 읽으므로 안전하게 종료.
    if any(info[k][1] != FLOAT32 for k in ('x', 'y', 'z')):
        return np.empty((0, 3), dtype=np.float32)

    step  = msg.point_step
    n_pts = msg.width * msg.height
    if step <= 0 or n_pts == 0:
        return np.empty((0, 3), dtype=np.float32)

    # 버퍼가 기대보다 짧으면(잘린/손상 메시지) count 를 줄여 frombuffer 크래시 방지.
    # ★ bytes(msg.data) 는 클라우드마다 버퍼 전체(수백 KB)를 복사한다. rclpy 가 주는
    #   data 는 이미 버퍼 프로토콜을 지원하므로 그대로 frombuffer 에 넘긴다.
    buf = msg.data
    try:
        n_bytes = len(buf)
    except TypeError:                      # 버퍼 프로토콜이 아니면 안전하게 복사
        buf = bytes(buf)
        n_bytes = len(buf)
    n_pts = min(n_pts, n_bytes // step)
    if n_pts == 0:
        return np.empty((0, 3), dtype=np.float32)

    # np.frombuffer + 구조화 dtype 으로 전체 포인트를 한 번에 파싱 (벡터화).
    f4 = '>f4' if msg.is_bigendian else '<f4'
    pt_dtype = np.dtype({
        'names':   ['x', 'y', 'z'],
        'formats': [f4, f4, f4],
        'offsets': [info['x'][0], info['y'][0], info['z'][0]],
        'itemsize': step,
    })
    arr = np.frombuffer(buf, dtype=pt_dtype, count=n_pts)
    xyz = np.empty((n_pts, 3), dtype=np.float32)
    xyz[:, 0], xyz[:, 1], xyz[:, 2] = arr['x'], arr['y'], arr['z']
    return xyz


def remove_ground_water(
    xy: np.ndarray, z: np.ndarray,
    grid_m: float, vert_min_m: float, top_min_m: float,
) -> tuple[np.ndarray, np.ndarray]:
    """
    지면·수면 제거 — XY 격자 셀 단위 '수직 구조' 검사.

    각 셀에서 z 높이차(zmax−zmin) ≥ vert_min  또는  zmax ≥ top_min 이면
    장애물 셀로 보고 그 셀의 모든 포인트를 유지(장애물 기둥 밑동까지 보존).
    그 외(평평하고 얇게 깔린 지면·수면)는 제거.

    절대 높이가 아닌 '국소 수직 분포'로 판정하므로 선체 pitch/roll 로
    지면이 기울어도(고정 높이 밴드보다) 견고하게 동작.
    """
    if len(xy) == 0:
        return xy, z
    # 셀 좌표를 int64 키 하나로 접어 1D 로 처리한다.
    #   · np.unique(axis=0) 는 행 단위 정렬이라 1D 대비 몇 배 느리고
    #   · np.minimum.at / maximum.at 은 numpy 에서 특히 느린 경로다.
    # 정렬 한 번 + reduceat 으로 같은 결과를 낸다 (pc2_util.remove_ground_to_2d 와 동일 기법).
    cells = np.floor(xy / grid_m).astype(np.int64)
    cx = cells[:, 0] - cells[:, 0].min()
    cy = cells[:, 1] - cells[:, 1].min()
    key = cx * (cy.max() + 1) + cy                      # 충돌 없는 1D 키
    order = np.argsort(key, kind='stable')
    ks, zs = key[order], z[order]
    uniq, start = np.unique(ks, return_index=True)
    zmax = np.maximum.reduceat(zs, start)
    zmin = np.minimum.reduceat(zs, start)
    cell_is_obs = ((zmax - zmin) >= vert_min_m) | (zmax >= top_min_m)
    keep = cell_is_obs[np.searchsorted(uniq, key)]
    return xy[keep], z[keep]


def voxel_downsample_2d(xy: np.ndarray, voxel_m: float) -> np.ndarray:
    """XY 복셀 셀당 대표 1점만 남겨 밀도 균일화 (장애물 표현 선명·연산 절감)."""
    if len(xy) <= 1:
        return xy
    cells = np.floor(xy / voxel_m).astype(np.int64)
    cx = cells[:, 0] - cells[:, 0].min()
    cy = cells[:, 1] - cells[:, 1].min()
    _, idx = np.unique(cx * (cy.max() + 1) + cy, return_index=True)
    return xy[np.sort(idx)]


def pointcloud_to_points(
    msg: PointCloud2,
    ignore_r: float,
    max_r: float,
    min_height: float,
    max_height: float,
    angle_min: float,
    angle_max: float,
    cluster_min: int,
    cluster_gap: float,
    ground_grid: float = 0.0,
    ground_vert_min: float = 0.2,
    ground_top_min: float = 0.5,
    voxel_size: float = 0.0,
) -> np.ndarray:
    """
    PointCloud2 → 2D 바디프레임 장애물 배열 (N, 2).
    x=전방, y=좌측 (로컬 ENU).

    필터링 순서:
      1. NaN / Inf 제거
      2. 높이(z) coarse 밴드: [min_height, max_height]  — 명백한 하부/상부 컷
      3. 수평 거리 필터: [ignore_r, max_r]
      4. 수평 각도 필터: [angle_min, angle_max]  — 전방 FOV
      5. 지면/수면 제거: 격자별 수직 구조 검사 (ground_grid > 0 일 때)
      6. 복셀 다운샘플: 밀도 균일화 (voxel_size > 0 일 때)
      7. 클러스터 필터: 고립 노이즈 포인트 제거
    """
    xyz = _parse_pc2_xyz(msg)
    if len(xyz) == 0:
        return np.empty((0, 2))

    # 1~4. NaN/높이/거리/FOV 를 '마스크 하나' 로 합쳐 gather 를 1회만 한다.
    #   기존에는 단계마다 배열 전체를 새로 만들어(4회 복사) 2만 점을 네 번 훑었다.
    #   특히 실측상 점의 73% 가 (0,0,0) 패딩인데 그걸 지우는 거리 필터가 3번째라
    #   앞의 두 패스를 통째로 낭비했다. 마스크는 모두 원소별 술어라 결합해도
    #   결과 집합·순서가 동일하다(불리언 인덱싱은 원래 순서를 보존).
    # ⚠️ 높이 비교는 반드시 float32 원본으로 한다. float64 로 먼저 올리면
    #    float32(-0.1) = -0.100000001490… < float64(-0.1) 이 되어 밴드 경계에
    #    정확히 걸친 점(실측: 프레임당 약 5점, z == min_height)이 탈락한다.
    zf = xyz[:, 2]
    x = xyz[:, 0].astype(np.float64)
    y = xyz[:, 1].astype(np.float64)

    r2 = x * x + y * y                                  # sqrt 없이 제곱거리로 비교
    # isfinite 는 술어라 float32/float64 어느 쪽으로 재도 결과가 같다.
    # (N,3) 전체를 훑는 np.all(..., axis=1) 대신 1-D 세 번이 더 싸다.
    keep = (np.isfinite(x) & np.isfinite(y) & np.isfinite(zf)
            & (zf >= min_height) & (zf <= max_height)
            & (r2 > ignore_r * ignore_r) & (r2 < max_r * max_r))
    if not keep.any():
        return np.empty((0, 2))

    xy = np.column_stack([x[keep], y[keep]])
    z  = zf[keep].astype(np.float64)

    # FOV 는 남은 점에만 적용. arctan2 는 초월함수라 입력 메모리 레이아웃에 따라
    # ULP 가 달라질 수 있어, 경계(±angle) 판정이 뒤집히지 않도록 기존과 동일하게
    # (M,2) 배열의 열 슬라이스를 넘긴다.
    angles = np.arctan2(xy[:, 1], xy[:, 0])
    keep2 = (angles >= angle_min) & (angles <= angle_max)
    if not keep2.any():
        return np.empty((0, 2))
    xy, z = xy[keep2], z[keep2]

    # 5. 지면/수면 제거 (격자별 수직 구조)
    if ground_grid > 0.0:
        xy, z = remove_ground_water(xy, z, ground_grid, ground_vert_min, ground_top_min)
        if len(xy) == 0:
            return np.empty((0, 2))

    # 6. 복셀 다운샘플 (선택) — 장애물 점밀도 균일화
    if voxel_size > 0.0:
        xy = voxel_downsample_2d(xy, voxel_size)

    # 7. 클러스터 필터 (각도 순 정렬 후 인접 포인트 간 거리 기반)
    order = np.argsort(np.arctan2(xy[:, 1], xy[:, 0]))
    xy = xy[order]
    keep = np.zeros(len(xy), dtype=bool)
    gaps = np.linalg.norm(np.diff(xy, axis=0), axis=1) if len(xy) > 1 else np.array([])
    start = 0
    for i in range(len(gaps) + 1):
        if (i == len(gaps)) or (gaps[i] > cluster_gap):
            if (i - start + 1) >= cluster_min:
                keep[start: i + 1] = True
            start = i + 1
    return xy[keep]


# ═══════════════════════════════════════════════════════════════════════════════
#  경로 계획 (순수 함수) — 아크뱅크 벡터화 / clearance·히스테리시스
# ═══════════════════════════════════════════════════════════════════════════════

def simulate_arc_bank(speed: float, rates: np.ndarray, T: float, dt: float) -> np.ndarray:
    """
    모든 yaw rate 의 등속 원호 궤적을 한 번에 생성 (벡터화). 반환: (R, K, 2).
    기존 simulate_arc 의 루프와 수치적으로 동일:
      traj[i] = speed·dt · Σ_{j=0}^{i} (cos(rate·dt·j), sin(rate·dt·j))
    ※ 궤적 위치는 speed 에 선형 비례(theta 는 speed 무관)하므로
       speed=1 단위뱅크를 한 번 만들고 런타임엔 speed 스칼라만 곱하면 됨.
    """
    steps = max(1, int(T / dt))
    j = np.arange(steps)                              # (K,)
    theta = rates[:, None] * (dt * j)[None, :]        # (R, K)
    dx = speed * dt * np.cos(theta)
    dy = speed * dt * np.sin(theta)
    return np.stack([np.cumsum(dx, axis=1), np.cumsum(dy, axis=1)], axis=2)


def arc_collides(traj: np.ndarray, obs: np.ndarray, r: float) -> bool:
    """궤적 상의 임의 점이 장애물 r 이내에 있으면 True (직진 경로 체크용)."""
    if len(obs) == 0 or len(traj) == 0:
        return False
    d = traj[:, None, :] - obs[None, :, :]
    return bool(np.any(np.einsum('kmd,kmd->km', d, d) < r * r))


def straight_path(dist: float, rel_yaw: float, max_spd: float, sim_t: float, safety_r: float) -> np.ndarray:
    """충돌 체크용 직진 경로 샘플링 (바디프레임)."""
    path_len = min(dist, max(max_spd * sim_t, safety_r))
    steps = max(2, int(path_len / 0.2) + 1)
    s = np.linspace(0.0, path_len, steps)
    return np.column_stack([s * math.cos(rel_yaw), s * math.sin(rel_yaw)])


def clearance_per_arc(trajs: np.ndarray, obs: np.ndarray) -> np.ndarray:
    """각 아크(R개)의 궤적-장애물 최소 거리 (R,). 장애물 없으면 inf."""
    R = trajs.shape[0]
    if len(obs) == 0:
        return np.full(R, np.inf)
    # 아크별 파이썬 루프(R=21회) 제거. 산술은 기존과 동일한 브로드캐스트 뺄셈이라
    # 부동소수점 결과까지 같다(대수적 항등식으로 바꾸면 경계에서 판정이 뒤집힐 수 있음).
    d = trajs[:, :, None, :] - obs[None, None, :, :]     # (R, K, M, 2)
    d2 = np.einsum('rkmd,rkmd->rkm', d, d)               # (R, K, M)
    return np.sqrt(d2.reshape(R, -1).min(axis=1))


def evaluate_bank(
    trajs: np.ndarray,
    rates: np.ndarray,
    goal_yaw_rel_enu: float,
    obs: np.ndarray,
    T: float,
    r: float,
    w_clear: float,
    clear_scale: float,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    아크뱅크 평가 (dict 미할당, 전부 ndarray).
    반환: (collision(R,) bool, scores(R,), dmins(R,))
      score = 목표정렬(rate·T 지평) + w_clear·(안전반경 초과 여유 정규화)
      충돌 아크의 score = -inf. 동률은 직진(|rate| 작은 쪽) 미세 선호.
    """
    dmins = clearance_per_arc(trajs, obs)
    collision = dmins < r
    # 목표 정렬: 아크가 T초 뒤 트는 각(rate·T)과 목표 상대각 차이 (명령과 동일 지평)
    head_change = rates * T
    align = np.abs((head_change - goal_yaw_rel_enu + np.pi) % (2.0 * np.pi) - np.pi) / np.pi
    scores = (1.0 - align) + w_clear * np.clip((dmins - r) / clear_scale, 0.0, 1.0)
    scores = scores - 1e-6 * np.abs(rates)            # 동률 tiebreak → 직진 선호
    scores[collision] = -np.inf
    return collision, scores, dmins


def select_best(scores: np.ndarray, collision: np.ndarray, prev_idx: int, margin: float) -> int:
    """
    충돌 없는 아크 중 최고 score 인덱스 (히스테리시스 적용). 전부 막히면 -1.
    직전 선택이 여전히 유효하면, 새 후보가 margin 이상 더 좋을 때만 전환(떨림 억제).
    """
    valid = ~collision
    if not valid.any():
        return -1
    best = int(np.argmax(np.where(valid, scores, -np.inf)))
    if 0 <= prev_idx < len(scores) and valid[prev_idx]:
        if scores[best] <= scores[prev_idx] + margin:
            return prev_idx
    return best


# ═══════════════════════════════════════════════════════════════════════════════
#  디버그 마커 빌더
# ═══════════════════════════════════════════════════════════════════════════════

def _marker(header, ns: str, mid: int, mtype: int) -> Marker:
    m = Marker()
    m.header = header
    m.ns, m.id, m.type = ns, mid, mtype
    m.action = Marker.ADD
    m.scale.x = m.scale.y = m.scale.z = 0.1
    m.color.a = 1.0
    return m


def build_arc_markers(trajs: np.ndarray, collision: np.ndarray, best_idx: int,
                      header, emergency: bool = False) -> MarkerArray:
    ma = MarkerArray()
    for i in range(trajs.shape[0]):
        m = _marker(header, 'arcs', i, Marker.LINE_STRIP)
        if i == best_idx:
            if emergency:
                # 비상 경로(전 경로 차단): 진한 초록 + 굵게
                m.color.r, m.color.g, m.color.b, m.color.a = 1.0, 1.0, 1.0, 1.0
                m.scale.x = 0.15
            else:
                # 일반 선택 경로: 파랑 + 굵게
                m.color.b, m.color.a, m.scale.x = 1.0, 1.0, 0.15
        elif collision[i]:
            m.color.r, m.color.a = 1.0, 0.6
        else:
            m.color.g, m.color.a = 1.0, 0.5
        for xy in trajs[i]:
            pt = Point(); pt.x, pt.y = float(xy[0]), float(xy[1])
            m.points.append(pt)
        ma.markers.append(m)
    return ma


def build_direct_marker(path: np.ndarray, header) -> MarkerArray:
    ma = MarkerArray()
    m = _marker(header, 'arcs', 0, Marker.LINE_STRIP)
    m.color.b, m.color.a, m.scale.x = 1.0, 1.0, 0.10
    for xy in path:
        pt = Point(); pt.x, pt.y = float(xy[0]), float(xy[1])
        m.points.append(pt)
    ma.markers.append(m)
    return ma


def build_obstacle_markers(obs: np.ndarray, header) -> MarkerArray:
    ma = MarkerArray()
    if len(obs) == 0:
        return ma
    m = _marker(header, 'obstacles', 100, Marker.POINTS)
    m.scale.x = m.scale.y = 0.10
    m.color.r, m.color.g, m.color.a = 1.0, 1.0, 0.9
    for xy in obs:
        pt = Point(); pt.x, pt.y = float(xy[0]), float(xy[1])
        m.points.append(pt)
    ma.markers.append(m)
    return ma


def build_status_marker(
    mode: str, speed: float, dist_to_goal: float, closest: float,
    has_goal: bool, header,
) -> MarkerArray:
    ma = MarkerArray()
    m = _marker(header, 'status', 200, Marker.TEXT_VIEW_FACING)
    m.pose.position.x = 3.0
    m.pose.position.y = 3.0
    m.pose.position.z = 2.0
    m.scale.z = 0.4
    m.color.r = m.color.g = m.color.b = m.color.a = 1.0
    goal_str = f'{dist_to_goal:.1f} m' if has_goal else 'None'
    m.text = (
        f'[{mode}]\n'
        f'velocity: {speed:.2f} m/s\n'
        f'dist_goal: {goal_str}\n'
        f'min_obs: {closest:.2f} m'
    )
    ma.markers.append(m)
    return ma


def publish_all(pub, *marker_arrays) -> None:
    combined = MarkerArray()
    # 직전 프레임 마커를 모두 삭제하고 현재 상태만 새로 그림 (stale marker 방지)
    clear = Marker()
    clear.action = Marker.DELETEALL
    combined.markers.append(clear)
    for ma in marker_arrays:
        combined.markers.extend(ma.markers)
    pub.publish(combined)


# ═══════════════════════════════════════════════════════════════════════════════
#  노드
# ═══════════════════════════════════════════════════════════════════════════════

class CollisionAvoidanceNodeLivox(Node):

    def __init__(self):
        super().__init__('collision_avoidance_node_livox')
        self._declare_params()
        self._load_params()

        sensor_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        # ── 시동 가드: 절대방위 명령으로 표현 가능한 선회각인가 ──────────────
        # 명령은 angular.z = 절대 NED 방위각이라 mod 360° 다. rate×T 가 180° 를
        # 넘으면 "270° 우선회" 와 "90° 좌선회" 가 구분되지 않아 PID 가 짧은 쪽으로
        # 돌고, 충돌 검사한 아크와 반대 경로를 실제로 가게 된다.
        # ★ 검사 대상은 SIM_T 가 아니라 CMD_T 다. 명령은 rate×CMD_T 로 나가므로
        #   (아래 _twist/ned_yaw 호출부) 랩어라운드를 일으키는 것도 CMD_T 다.
        #   SIM_T 로 검사하면 (a) cmd_horizon_sec 로 명령 지평을 짧게 잡아도
        #   예측 지평만 길다는 이유로 yaw_rate 를 불필요하게 깎고,
        #   (b) 반대로 CMD_T > SIM_T 인 설정은 가드를 통과한 채 명령이 뒤집힌다.
        _span = self.MAX_YAW_RATE * self.CMD_T
        _limit = math.radians(150.0)                  # 180° 에 30° 마진
        if _span > _limit:
            self.get_logger().error(
                f'max_yaw_rate×cmd_horizon = {math.degrees(_span):.0f}° > '
                f'{math.degrees(_limit):.0f}° — 절대방위 명령으로 표현 불가. '
                f'yaw_rate 를 {math.degrees(_limit / self.CMD_T):.1f}°/s 로 클리핑한다.')
            self.MAX_YAW_RATE = _limit / self.CMD_T

        # [6] 아크 배치. 'quad' 는 중앙 조밀·외곽 성김.
        #   실측: 회피 154회 중 극단 아크(0,1,19,20) 선택은 1.3% 뿐이고
        #   ±22°/s 안쪽이 대부분인데 ±55°/s 에 균등 배치하니 실제 쓰는 구간의
        #   해상도가 5.5°/s 밖에 안 됐다. u² 배치로 중앙 해상도가 약 2배가 되고
        #   극단 아크는 그대로 남아 HOLD-Escape·비상 탈출에 쓸 수 있다.
        #   ⚠️ 다만 폐루프 시뮬(VRX WAM-V, max_yaw 12°/s)에서는 외곽이 성겨져
        #      탈출 선택지가 줄어드는 것으로 의심된다. 기본값은 'uniform' 이다.
        if self.ARC_SPACING == 'quad':
            _u = np.linspace(-1.0, 1.0, self.ARC_COUNT)
            self._rates = self.MAX_YAW_RATE * np.sign(_u) * _u * _u
        else:
            self._rates = np.linspace(-self.MAX_YAW_RATE, self.MAX_YAW_RATE, self.ARC_COUNT)
        # 단위속도(=1) 아크뱅크 1회 precompute. 궤적은 speed 에 선형 비례하므로
        # 런타임엔 speed 스칼라만 곱해 재사용(매 프레임 trig/적분 제거).
        self._arc_unit = simulate_arc_bank(1.0, self._rates, self.SIM_T, self.SIM_DT)  # (R,K,2)
        self._prev_idx = -1   # 히스테리시스용 직전 선택 아크 인덱스
        self._t_straight: int | None = None   # [5] 연속 직진 시작 시각 [ns]

        self._pos_ned:  np.ndarray | None = None
        self._heading:  float | None      = None
        self._goal_ned: np.ndarray | None = None
        self._obs:      np.ndarray        = np.empty((0, 2))
        self._pc_hdr                      = None
        # operation_mode (Simulink 발행): 1=WP추종 2=loiter 3=충돌회피 4=docking
        #   None = 아직 수신 안 됨 → gating 통과 안 함(안전측)
        self._op_mode:  int | None        = None
        # 마지막 수신 시각 [ns] — staleness(센서 끊김) 감지용
        self._t_pos:     int | None       = None
        self._t_heading: int | None       = None
        self._t_cloud:   int | None       = None
        self._t_goal:    int | None       = None
        # 클라우드가 찍힌 시점의 자세 (자기운동 보정용)
        self._obs_pos:   np.ndarray | None = None
        self._obs_hdg:   float | None      = None

        self.create_subscription(Point,        '/usv/state/position_ned', self._cb_pos,     sensor_qos)
        self.create_subscription(Float32,      '/usv/state/heading',      self._cb_heading, sensor_qos)
        self.create_subscription(Point,        '/usv/state/goal_ned',     self._cb_goal,    sensor_qos)
        self.create_subscription(PointCloud2,  '/livox/lidar',            self._cb_cloud,   sensor_qos)
        self.create_subscription(OperationMode, '/fmu/out/operation_mode', self._cb_op_mode, sensor_qos)

        self._pub_cmd   = self.create_publisher(Twist,       '/vfh/command',        10)
        self._pub_flag  = self.create_publisher(Bool,        '/vfh/oa_flag',        10)
        self._pub_debug = self.create_publisher(MarkerArray, self.DEBUG_TOPIC, 10)

        self.create_timer(1.0 / self.RATE_HZ, self._loop)
        self.get_logger().info('CollisionAvoidanceNodeLivox Ready!! (input: /livox/lidar)')

    # ── 파라미터 ──────────────────────────────────────────────────────────────

    def _declare_params(self):
        self.declare_parameters('', [
            ('sys.rate_hz',               20.0),
            ('sys.sensor_timeout_sec',    0.15),   # 센서 입력 stale 판정 시간 [s]
            ('sys.active_mode',            3),      # 이 operation_mode 일 때만 동작 (3=충돌회피)
            # 목표(goal_ned) 전용 timeout [s]. 0 = 무제한(강등 없음).
            # ⚠️ sensor_timeout_sec 를 쓰면 안 된다 — goal_ned 는 웨이포인트가
            #    바뀔 때만 발행되는 '이벤트' 토픽이다. 실측(bag 6종): 발행 6~8회,
            #    간격 2.4 s ~ 119.5 s. 0.15 s 로 재면 항상 stale → 영구 HOLD.
            ('sys.goal_timeout_sec',       0.0),
            ('robot.max_speed_m_s',        2.5),
            ('robot.max_yaw_rate_deg_s',  50.0),   # 90 은 rate×T=270° 로 명령이 뒤집힘(아래 가드 참조)
            ('robot.safety_radius_m',      0.60),
            ('plan.sim_time_sec',          3.0),
            ('plan.sim_steps',            15),
            ('plan.arc_count',            21),
            ('plan.hysteresis_margin',     0.10),  # 직전 선택 전환 임계(클수록 떨림↓·반응↓)
            ('plan.clearance_weight',      0.30),  # 점수 내 여유(clearance) 가중치
            ('plan.clearance_scale_m',     3.0),   # 여유 정규화 스케일 [m]
            ('plan.blocked_speed_scale',   0.3),   # (참고) [3] 단계축소가 대신함
            ('plan.creep_scales',    [0.6, 0.3, 0.15, 0.08]),  # [3] 비상 시 시도할 지평 배율
            ('plan.straight_reset_sec',    1.0),   # [5] 이 시간 연속 직진해야 히스테리시스 리셋
            ('plan.arc_spacing',    'uniform'),    # [6] 'uniform' | 'quad'(중앙 조밀)
            ('plan.creep_min_clear_ratio', 1.0),   # [3] 서행 허용 최소 여유 (안전반경 배수)
            ('plan.cmd_horizon_sec',       0.0),   # 0=기존 동작(SIM_T 사용). >0 이면 그 지평으로 명령   # 모든 아크 차단 시 감속 배율 (0~1)
            # 디버그 마커 발행 토픽. bag 재생과 겹치지 않게 바꿔 rviz2 에서
            # '녹화된 구코드 아크' 와 '지금 도는 노드의 아크' 를 겹쳐 볼 수 있다.
            ('debug.marker_topic', '/vfh/debug_markers'),
            ('hold.clear_m',               1.0),
            ('hold.escape_speed_m_s',      0.6),
            # lidar 필터 파라미터 (laserScan 버전과 동일 + 높이/각도 추가)
            ('lidar.ignore_radius_m',      0.5),
            ('lidar.cluster_min_points',   1),
            ('lidar.cluster_max_gap_m',    0.45),
            ('lidar.min_height_m',        -0.1),   # 수면 노이즈 제거
            ('lidar.max_height_m',         1.0),   # 상부 구조물 제거
            ('lidar.angle_half_fov_deg',  120.0),   # 전방 FOV 반각 [deg] → ±이 값으로 적용
            # 지면/수면 제거 (격자별 수직 구조 필터). grid=0 이면 비활성.
            ('lidar.ground_grid_m',       0.15),
            ('lidar.ground_vert_min_m',   0.08),
            ('lidar.ground_top_min_m',     0.3),
            # 복셀 다운샘플. 0 이면 비활성.
            ('lidar.voxel_size_m',         0.1),
        ])

    def _load_params(self):
        g = lambda name: self.get_parameter(name).value
        self.RATE_HZ        = float(g('sys.rate_hz'))
        self.SENSOR_TIMEOUT = float(g('sys.sensor_timeout_sec'))
        self.ACTIVE_MODE    = int(g('sys.active_mode'))
        self.GOAL_TIMEOUT   = float(g('sys.goal_timeout_sec'))
        self.MAX_SPEED    = float(g('robot.max_speed_m_s'))
        self.MAX_YAW_RATE = math.radians(float(g('robot.max_yaw_rate_deg_s')))
        self.SAFETY_R     = float(g('robot.safety_radius_m'))
        self.SIM_T        = float(g('plan.sim_time_sec'))
        self.SIM_DT       = self.SIM_T / int(g('plan.sim_steps'))
        self.ARC_COUNT    = int(g('plan.arc_count'))
        self.HYST_MARGIN  = float(g('plan.hysteresis_margin'))
        self.CLEAR_W      = float(g('plan.clearance_weight'))
        self.CLEAR_SCALE  = float(g('plan.clearance_scale_m'))
        self.BLOCKED_SPEED_SCALE = float(g('plan.blocked_speed_scale'))
        self.CREEP_SCALES = [float(x) for x in g('plan.creep_scales')]
        self.STRAIGHT_RESET = float(g('plan.straight_reset_sec'))
        self.ARC_SPACING = str(g('plan.arc_spacing'))
        self.CREEP_MIN_RATIO = float(g('plan.creep_min_clear_ratio'))
        _ch = float(g('plan.cmd_horizon_sec'))
        self.CMD_T        = _ch if _ch > 0.0 else self.SIM_T
        self.DEBUG_TOPIC  = str(g('debug.marker_topic'))
        self.HOLD_CLEAR   = float(g('hold.clear_m'))
        self.ESCAPE_SPEED = float(g('hold.escape_speed_m_s'))
        self.IGNORE_R     = float(g('lidar.ignore_radius_m'))
        self.MAX_RANGE    = self.MAX_SPEED * self.SIM_T + 2.0
        self.CLUSTER_MIN  = int(g('lidar.cluster_min_points'))
        self.CLUSTER_GAP  = float(g('lidar.cluster_max_gap_m'))
        self.MIN_HEIGHT   = float(g('lidar.min_height_m'))
        self.MAX_HEIGHT   = float(g('lidar.max_height_m'))
        half_fov          = math.radians(float(g('lidar.angle_half_fov_deg')))
        self.ANGLE_MIN    = -half_fov
        self.ANGLE_MAX    =  half_fov
        self.GROUND_GRID     = float(g('lidar.ground_grid_m'))
        self.GROUND_VERT_MIN = float(g('lidar.ground_vert_min_m'))
        self.GROUND_TOP_MIN  = float(g('lidar.ground_top_min_m'))
        self.VOXEL_SIZE      = float(g('lidar.voxel_size_m'))

    # ── 콜백 ──────────────────────────────────────────────────────────────────

    def _cb_pos(self,     msg: Point):   self._pos_ned = np.array([msg.x, msg.y]); self._t_pos = self._now_ns()
    def _cb_heading(self, msg: Float32): self._heading = float(msg.data);          self._t_heading = self._now_ns()
    def _cb_goal(self,    msg: Point):   self._goal_ned = np.array([msg.x, msg.y]); self._t_goal = self._now_ns()
    def _cb_op_mode(self, msg: OperationMode): self._op_mode = round(float(msg.operation_mode))

    def _now_ns(self) -> int:
        return self.get_clock().now().nanoseconds

    def _cb_cloud(self, msg: PointCloud2):
        self._pc_hdr = msg.header
        self._t_cloud = self._now_ns()
        # 점군을 만든 그 시점의 자세를 함께 박제 (자기운동 보정용)
        self._obs_pos = None if self._pos_ned is None else self._pos_ned.copy()
        self._obs_hdg = self._heading
        self._obs = pointcloud_to_points(
            msg,
            self.IGNORE_R, self.MAX_RANGE,
            self.MIN_HEIGHT, self.MAX_HEIGHT,
            self.ANGLE_MIN, self.ANGLE_MAX,
            self.CLUSTER_MIN, self.CLUSTER_GAP,
            self.GROUND_GRID, self.GROUND_VERT_MIN, self.GROUND_TOP_MIN,
            self.VOXEL_SIZE,
        )

    # ── 메인 제어 루프 ─────────────────────────────────────────────────────────

    def _straight_reset(self, now: int, prev_idx: int) -> int:
        """[5] 연속 직진이 STRAIGHT_RESET 초를 넘겼을 때만 히스테리시스를 지운다.

        직진할 때마다 지우면 직진↔회피 경계에서 히스테리시스가 전혀 작동하지
        않는다. 실측: 명령 방위의 사이클 간 변화가 30° 를 넘는 사이클 4.0%,
        최대 177.8°.
        """
        if self._t_straight is None:
            self._t_straight = now
            return prev_idx
        if (now - self._t_straight) * 1e-9 >= self.STRAIGHT_RESET:
            return -1
        return prev_idx

    def _stale(self, t: int | None, now: int) -> bool:
        """수신 시각이 없거나 timeout 초과면 True."""
        return t is None or (now - t) * 1e-9 > self.SENSOR_TIMEOUT

    def _goal_stale(self, now: int) -> bool:
        """목표 전용 staleness. GOAL_TIMEOUT<=0 이면 강등하지 않는다.

        goal_ned 는 웨이포인트 변경 시에만 발행되는 이벤트 토픽이라 센서용
        SENSOR_TIMEOUT(0.15 s)으로 재면 수신 직후부터 항상 stale 이 된다.
        """
        if self.GOAL_TIMEOUT <= 0.0:
            return False
        return self._t_goal is None or (now - self._t_goal) * 1e-9 > self.GOAL_TIMEOUT

    def _loop(self):
        # ── operation_mode gating ─────────────────────────────────────────────
        # 이 노드는 operation_mode == ACTIVE_MODE(기본 3=충돌회피) 일 때만 동작한다.
        # 그 외 모드이거나 아직 모드 수신 전(None)이면 '침묵' — 아무 명령도 발행하지
        # 않아 다른 유도(Simulink 내부/도킹 등)를 방해하지 않는다.
        if self._op_mode != self.ACTIVE_MODE:
            self._prev_idx = -1   # 재진입 시 히스테리시스 초기화
            self._t_straight = None
            self.get_logger().info(
                f'operation_mode={self._op_mode} (≠{self.ACTIVE_MODE}) — 대기(침묵).',
                throttle_duration_sec=5.0)
            return

        if self._pos_ned is None or self._heading is None:
            return

        # ── 센서 staleness 페일세이프 ─────────────────────────────────────────
        # 위치·헤딩·포인트클라우드 중 하나라도 끊기면 옛 데이터로 주행하지 않고 정지.
        now = self._now_ns()
        if (self._stale(self._t_pos, now) or self._stale(self._t_heading, now)
                or self._stale(self._t_cloud, now)):
            self._pub_cmd.publish(self._twist(0.0, self._heading))
            self._pub_flag.publish(self._bool(False))
            self.get_logger().warn('센서 입력 stale — 정지 유지.', throttle_duration_sec=2.0)
            return

        # ── C3: 목표 staleness — 끊기면 HOLD 로 강등 ─────────────────────────
        # 목표에는 원래 stale 검사도 초기화 경로도 없어서, WP 스트림이 끊겨도
        # 옛 목표로 전속 주행하고 HOLD 로 돌아갈 수 없었다.
        if self._goal_ned is not None and self._goal_stale(now):
            self.get_logger().warn('goal stale — HOLD 로 강등.', throttle_duration_sec=2.0)
            self._goal_ned = None
            self._t_goal = None

        # ── C2: 자기운동 보정 ────────────────────────────────────────────────
        # 장애물은 클라우드 시점 프레임에 있고 아크는 현재 원점에서 출발한다.
        obs = self._obs
        if len(obs) and self._obs_pos is not None and self._obs_hdg is not None:
            obs = compensate_ego(obs, self._obs_pos, self._obs_hdg,
                                 self._pos_ned, self._heading)
        hdr     = self._pc_hdr
        dbg     = hdr is not None and self._pub_debug.get_subscription_count() > 0
        closest = float(np.min(np.linalg.norm(obs, axis=1))) if len(obs) else math.inf

        # ── HOLD MODE ─────────────────────────────────────────────────────────
        if self._goal_ned is None:
            # 전방 HOLD_CLEAR 거리 경로가 장애물과 충돌하지 않으면 정지 유지.
            # 옆/뒤 장애물이 가까워도 전방이 열려 있으면 이탈 불필요.
            fwd_path      = straight_path(self.HOLD_CLEAR, 0.0, self.ESCAPE_SPEED, self.SIM_T, self.SAFETY_R)
            forward_clear = not arc_collides(fwd_path, obs, self.SAFETY_R)
            if forward_clear:
                self._prev_idx = self._straight_reset(now, self._prev_idx)
                self._pub_cmd.publish(self._twist(0.0, self._heading))
                self._pub_flag.publish(self._bool(False))
                if dbg:
                    publish_all(self._pub_debug,
                                build_obstacle_markers(obs, hdr),
                                build_status_marker('HOLD — Stop', 0.0, 0.0, closest, False, hdr))
            else:
                centroid   = np.mean(obs, axis=0)
                escape_enu = math.atan2(-centroid[1], -centroid[0])
                trajs      = self.ESCAPE_SPEED * self._arc_unit
                collision, scores, dmins = evaluate_bank(
                    trajs, self._rates, escape_enu, obs,
                    self.SIM_T, self.SAFETY_R, self.CLEAR_W, self.CLEAR_SCALE)
                # ★ self._prev_idx 를 먼저 덮어쓰면 폴백에 -1 이 전달되어
                #   히스테리시스가 꺼진다(select_best 는 0<=prev 일 때만 적용).
                #   직전 선택을 지역변수로 붙잡아 두고 폴백에 넘긴다.
                _prev_keep = self._prev_idx
                best_idx = select_best(scores, collision, _prev_keep, self.HYST_MARGIN)
                if best_idx == -1:
                    # 전부 막힘: 여유 최대 아크를 히스테리시스와 함께 고른다.
                    best_idx = select_best(dmins, np.zeros(len(dmins), dtype=bool),
                                           _prev_keep, self.HYST_MARGIN)
                self._prev_idx = best_idx
                rate = float(self._rates[best_idx])
                self._pub_cmd.publish(self._twist(self.ESCAPE_SPEED, ned_yaw(self._heading, rate * self.CMD_T)))
                self._pub_flag.publish(self._bool(True))
                if dbg:
                    publish_all(self._pub_debug,
                                build_arc_markers(trajs, collision, best_idx, hdr),
                                build_obstacle_markers(obs, hdr),
                                build_status_marker('HOLD — Escape', self.ESCAPE_SPEED, 0.0, closest, False, hdr))
            return

        # ── GOAL MODE ─────────────────────────────────────────────────────────
        diff         = self._goal_ned - self._pos_ned
        dist         = float(np.linalg.norm(diff))
        spd          = self.MAX_SPEED
        goal_yaw_ned = math.atan2(diff[1], diff[0])
        rel_yaw_enu  = -pi2pi(goal_yaw_ned - self._heading)
        dpath        = straight_path(dist, rel_yaw_enu, self.MAX_SPEED, self.SIM_T, self.SAFETY_R)

        if not arc_collides(dpath, obs, self.SAFETY_R):
            # [5] 직진할 때마다 지우면 직진↔회피 경계에서 히스테리시스가
            #     전혀 작동하지 않는다(실측: 30° 초과 명령 점프 4.0%).
            #     일정 시간 연속 직진일 때만 지운다.
            self._prev_idx = self._straight_reset(now, self._prev_idx)
            self._pub_cmd.publish(self._twist(spd, ned_yaw(self._heading, rel_yaw_enu)))
            self._pub_flag.publish(self._bool(False))
            if dbg:
                publish_all(self._pub_debug,
                            build_direct_marker(dpath, hdr),
                            build_obstacle_markers(obs, hdr),
                            build_status_marker('Straight', spd, dist, closest, True, hdr))
        else:
            trajs = spd * self._arc_unit
            collision, scores, dmins = evaluate_bank(
                trajs, self._rates, rel_yaw_enu, obs,
                self.SIM_T, self.SAFETY_R, self.CLEAR_W, self.CLEAR_SCALE)
            # ★ 아래 비상 폴백들이 '직전 선택' 을 필요로 한다. self._prev_idx 를
            #   여기서 덮어쓰면 -1 이 전달되어 히스테리시스가 꺼진다.
            _prev_keep = self._prev_idx
            best_idx = select_best(scores, collision, _prev_keep, self.HYST_MARGIN)
            self._prev_idx = best_idx
            if best_idx != -1:
                self._t_straight = None
                rate, mode = float(self._rates[best_idx]), f'Avoidance (Route {best_idx})'
                marker_idx, emergency = best_idx, False
            else:
                # ── [3] 전 아크 차단 — 단계적 지평 축소 ───────────────────────
                # 감속은 곧 예측 지평 축소다(궤적이 속도에 선형 비례). 한 번에
                # ×0.3 으로 떨구지 말고 통과할 때까지 단계적으로 줄인다.
                #   실측(비상 68회): ×0.6 통과 14 / ×0.3 통과 17 / ×0.15 통과 9
                #                    / ×0.08 통과 6 / 전부막힘 22
                #   고정 ×0.3 이면 완전정지 37회 → 단계축소면 22회
                # 배는 비상 구간에서도 중앙 0.40 m/s 로 계속 움직이고 있었다.
                self._t_straight = None
                chosen = None
                for _sc in self.CREEP_SCALES:
                    _d = clearance_per_arc(_sc * trajs, obs)
                    _i = select_best(_d, np.zeros(len(_d), dtype=bool),
                                     _prev_keep, self.HYST_MARGIN)
                    if _d[_i] >= self.SAFETY_R:
                        chosen = (_sc, _i, float(_d[_i]))
                        break
                emergency = True
                if chosen is not None:
                    _sc, marker_idx, _clr = chosen
                    spd = self.MAX_SPEED * _sc
                    mode = f'Blocked — creep x{_sc:.2f} ({_clr:.2f} m)'
                else:
                    # 가장 짧은 지평조차 막혔다 → 전진하지 않고 제자리 선회
                    _sc = self.CREEP_SCALES[-1]
                    _d = clearance_per_arc(_sc * trajs, obs)
                    marker_idx = select_best(_d, np.zeros(len(_d), dtype=bool),
                                             _prev_keep, self.HYST_MARGIN)
                    # ★ 완전정지(spd=0)는 넣지 않는다. 폐루프 시뮬에서 확인한 바로는
                    #   정지하면 상황이 바뀌지 않아 교착에 갇힌다:
                    #     A0(항상 최소 서행, 속도 0 표본 0%)  → S4·S6 통과
                    #     정지를 넣은 판(속도 0 표본 85~89%) → S4·S6 교착 실패
                    #   대신 가장 짧은 지평의 최소 속도로 계속 움직이며 빠져나간다.
                    #   실비행 로그에서도 배는 비상 구간 중앙 0.40 m/s 로 계속 움직였다.
                    spd = self.MAX_SPEED * _sc
                    mode = f'BLOCKED — min creep x{_sc:.2f}'
                    self.get_logger().error(
                        f'전 아크 차단 — 최단 지평({_sc:.2f})도 여유 {_d[marker_idx]:.2f} m '
                        f'< {self.SAFETY_R:.2f} m. 최소 서행({spd:.2f} m/s)으로 이탈 시도.',
                        throttle_duration_sec=1.0)
                self._prev_idx = marker_idx
                rate = float(self._rates[marker_idx])
                # 화면에 그리는 아크를 실제 명령(축소 궤적)과 일치시킨다.
                trajs = _sc * trajs
            self._pub_cmd.publish(self._twist(spd, ned_yaw(self._heading, rate * self.CMD_T)))
            self._pub_flag.publish(self._bool(True))
            if dbg:
                publish_all(self._pub_debug,
                            build_arc_markers(trajs, collision, marker_idx, hdr, emergency),
                            build_obstacle_markers(obs, hdr),
                            build_status_marker(mode, spd, dist, closest, True, hdr))

    # ── 메시지 생성 ───────────────────────────────────────────────────────────

    @staticmethod
    def _twist(speed: float, yaw_ned: float) -> Twist:
        msg = Twist()
        msg.linear.x, msg.angular.z = float(speed), float(yaw_ned)
        return msg

    @staticmethod
    def _bool(val: bool) -> Bool:
        msg = Bool()
        msg.data = val
        return msg


# ═══════════════════════════════════════════════════════════════════════════════
#  엔트리포인트
# ═══════════════════════════════════════════════════════════════════════════════

def main(args=None):
    rclpy.init(args=args)
    node = CollisionAvoidanceNodeLivox()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()