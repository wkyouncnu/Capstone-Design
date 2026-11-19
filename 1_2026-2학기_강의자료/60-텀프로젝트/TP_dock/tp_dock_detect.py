#!/usr/bin/env python3
"""tp_dock_detect.py — 도킹 스테이션 세 칸을 라이다 점군에서 찾아 WP1 기준으로 발행

출처
  2026 대회 코드 70-대회코드2026/.../ugv_docking_pkg 를 그대로 쓴다.
  검출 알고리즘은 한 줄도 새로 쓰지 않았다 — 이 파일은 **배선**만 한다.
    - pc2_util.remove_ground_to_2d  : PointCloud2 -> 지면 제거 2D 점군
    - bay_core.rectify              : PCA 로 벽 방향을 y 축에 정렬
    - bay_core.wall_band_filter     : 스테이션 앞 잡음 슬랩 제거
    - bay_core.find_bays_pillars    : 격벽 4 개를 찾고 그 사이 간격 3 개를 베이로
    - bay_core.PointAccumulator     : 정지 전제 점 축적
    - marker_viz.build_markers      : RViz2 MarkerArray
  네 파일 모두 대회 폴더에서 바이트 단위로 복사했다.

왜 포켓 방식이 아니라 기둥 방식인가
  - 대회 노드는 find_bays_pocket (안쪽으로 들어간 구간 = 베이) 을 쓴다.
    UGV 스테이션은 격벽 돌출이 0.5 m 라 그 방식이 맞는다.
  - 해양누리 스테이션은 격벽 돌출이 7.0 m 다. WP1 에서 보면 격벽이 양옆 베이의
    안쪽벽을 가려 프로파일에 빈 칸이 생기고, 베이 중심이 가린 만큼 밀린다
    (오프라인 실측 1.4~1.6 m 편향).
  - find_bays_pillars 는 가장 잘 찍히는 면인 **격벽**을 검출 주체로 삼고,
    인접 격벽 사이 간격을 베이로 본다. 대회 코드 주석이 바로 이 상황을 적어 두었다
    ("베이 안쪽 점이 부분적으로 비어도 양옆 기둥만 있으면 베이가 잡힌다").
  - 둘 다 대회 bay_core.py 안에 이미 있는 함수다. 고른 것일 뿐 새로 짜지 않았다.

바꾼 것 — 토픽 - 프레임 - 파라미터뿐

  | 항목 | 대회 | 여기 |
  |---|---|---|
  | 점군 토픽 | /livox/lidar | /wamv/sensors/lidars/lidar_wamv_sensor/points |
  | 자세 입력 | /fmu/out/* (PX4 uORB) | /wamv/sensors/position/ground_truth_odometry |
  | 출력 | /fmu/in/docking_test_param (px4_msgs) | /tp_dock/stations 외 (표준 메시지) |
  | 프레임 | livox_frame | wamv/wamv/base_link/lidar_wamv_sensor |
  | bin_w | 0.10 | 0.20 |
  | pillar_tol | 0.18 | 0.25 |
  | depth_min | 0.35 | 3.00 |
  | bay 폭 | 0.55 ~ 1.80 | 5.0 ~ 11.0 |
  | approach_dist | 0.80 | 6.00 |
  | band_depth | 0.70 | 9.00 |

발행점은 **입구면**이다 (대회와 의미가 다른 유일한 지점)
  - 대회 find_bays_pillars 의 idx = 간격 안쪽 깊은 점의 중앙값 = **안쪽 벽면**
  - 대회 스테이션은 깊이 0.35 m 라 안쪽 벽면이 곧 입구면이었음
  - 해양누리는 깊이 7.0 m — 실측 29.41 m 가 후벽(진실값 29.8 m) 으로 나왔음.
    그대로 목표로 쓰면 후벽을 향해 들어감
  - 그래서 격벽 앞면 기준거리 robust_pillar_baseline(= 입구면) 으로 입구를 다시 잡고
    깊이(= x_depth - pillar_x) 를 같이 발행한다. 안쪽 벽면은 `back` 으로 남긴다
  - 두 함수 모두 대회 bay_core.py 안에 있다. 대회 파일은 한 줄도 고치지 않았다

  px4_msgs 는 ~/vrx_ws/install 에 빌드돼 있지 않고, VRX 루프에 PX4 가 없다.
  검출부가 쓰는 커스텀 메시지는 3 개뿐이라 출력만 표준 메시지로 갈았다.

발행 토픽
  /tp_dock/stations       geometry_msgs/PoseArray
        pose[i].position.x = WP1 기준 d북 [m]
        pose[i].position.y = WP1 기준 d동 [m]
        pose[i].position.z = 칸 폭 [m]
        pose[i].orientation = 개구부가 향하는 방위 (ENU yaw, 쿼터니언)
        칸 순서는 서 -> 동 (네모 / 동그라미 / 세모)
  /tp_dock/stations_flat  std_msgs/Float32MultiArray
        [valid, locked, sel, dN0,dE0,az0,w0, dN1,dE1,az1,w1, dN2,dE2,az2,w2]
        az 는 북기준 시계방향 방위각 [deg]. MATLAB GUI 가 이 토픽을 읽는다
  /tp_dock/status         std_msgs/String   (ACCUM n/N -> DETECTED -> STABLE -> LOCKED)
  /tp_dock/debug_markers  visualization_msgs/MarkerArray  (대회 marker_viz 그대로)

실행
  python3 tp_dock_detect.py
  python3 tp_dock_detect.py --ros-args -p select:=2 -p wp1_north:=10.0
"""
import math
from collections import deque

import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import (qos_profile_sensor_data, QoSProfile, ReliabilityPolicy,
                       HistoryPolicy)

from geometry_msgs.msg import PoseArray, Pose
from nav_msgs.msg import Odometry
from sensor_msgs.msg import PointCloud2
from std_msgs.msg import Float32MultiArray, Float64MultiArray, Int32, String
from visualization_msgs.msg import MarkerArray

from pc2_util import pointcloud2_to_xyz, remove_ground_to_2d
from bay_core import (PointAccumulator, rectify, wall_band_filter,
                      find_bays_pillars, robust_pillar_baseline)
from marker_viz import build_markers

CLOUD_TOPIC = '/wamv/sensors/lidars/lidar_wamv_sensor/points'
ODOM_TOPIC = '/wamv/sensors/position/ground_truth_odometry'


def yaw_of(q):
    return math.atan2(2.0 * (q.w * q.z + q.x * q.y),
                      1.0 - 2.0 * (q.y * q.y + q.z * q.z))


def wrap(a):
    return (a + math.pi) % (2.0 * math.pi) - math.pi


class DockDetect(Node):

    def __init__(self):
        super().__init__('tp_dock_detect')
        d = self.declare_parameter

        # ROI, 지면 제거 (대회 roi.* / ground.*)
        d('roi.x_min', 2.0)   # 개구부 3~6 m 앞에서도 칸막이 끝면이 들어와야 한다
        d('roi.x_max', 30.0)
        d('roi.y_abs_max', 20.0)
        d('roi.z_min', -1.8)
        d('roi.z_max', 0.5)
        d('ground.cell', 0.30)
        d('ground.z_wall_min', -1.0)
        # 점 축적 (대회 accum.*)
        d('accum.enable', True)
        #  월드 좌표로 누적한다 — 선체계로 모으면 자세 표류(0.44 deg/s 실측) 가
        #  90 초 누적을 40 도에 걸쳐 문지른다. 월드로 모으면 접근 중에도 모을 수 있다
        d('accum.world', True)
        d('accum.voxel', 0.05)
        d('accum.target_pts', 4000)   # voxel 0.05 의 유니크 셀 상한은 약 7000 (0.10 은 1760 이라 4000 에 도달 못함)
        # 기둥 검출 (대회 bay.*)
        d('bay.band_depth', 9.0)
        d('bay.bin_w', 0.20)
        d('bay.min_pts_per_bin', 3)
        d('bay.depth_min', 3.0)
        d('bay.width_min', 5.0)
        d('bay.width_max', 11.0)
        d('bay.approach_dist', 6.0)
        d('bay.pillar_tol', 0.25)
        d('bay.pillar_width_min', 0.15)   # bin_w 0.20 의 0.75 칸 (대회 0.08/0.10 = 0.8 칸과 같은 비). 0.20 은 한 칸 폭과 같아 부동소수로 탈락
        d('bay.bridge_bins', 1)
        # 안정화, 잠금 (대회 stable.*)
        d('stable.thresh', 5)
        d('stable.smooth_window', 10)
        d('stable.pos_tol', 0.30)
        d('stable.psi_tol_deg', 5.0)
        d('stable.lock_duration', 1.0)
        # 월드 기준
        d('wp1_north', 10.0)
        d('wp1_east', 0.0)
        d('lidar_fwd', 0.70)    # 라이다 - base_link 전방 오프셋 (URDF 고정관절 합)
        d('select', 1)          # 목표 칸 0 서(네모) / 1 가운데(동그라미) / 2 동(세모)
        d('publish_hz', 5.0)
        d('dump_npz', '')        # 값을 주면 누적 점군을 한 번 npz 로 저장 (오프라인 대조용)
        d('viz.frame_id', 'wamv/wamv/base_link/lidar_wamv_sensor')

        self.P = lambda k: self.get_parameter(k).value
        P = self.P

        self.acc = PointAccumulator(P('accum.voxel'), P('accum.target_pts'))
        self.pose = None        # (북, 동, yaw_ENU)
        self.pts2d = None       # 검출에 쓴 2D 점군 (선체계)
        self.bays = []          # 선체계 베이
        self.world = []         # 월드 (북, 동, 개구부방위 rad, 폭, 접근wp북, 접근wp동)
        self.hist = [deque(maxlen=P('stable.smooth_window')) for _ in range(3)]
        self.stable_count = 0
        self.locked = False
        self.lock_t0 = None
        self.last_sm = None
        self.status = 'WAIT CLOUD'
        self.sel_cmd = None          # /tp_dock/select 로 들어온 값 — 파라미터보다 우선

        # 1 MB 급 점군은 BEST_EFFORT 로 받으면 통째로 유실된다 (실측: 콜백 0 회)
        qos_cloud = QoSProfile(reliability=ReliabilityPolicy.RELIABLE,
                               history=HistoryPolicy.KEEP_LAST, depth=1)
        self.create_subscription(PointCloud2, CLOUD_TOPIC,
                                 self.cb_cloud, qos_cloud)
        self.create_subscription(Odometry, ODOM_TOPIC,
                                 self.cb_odom, qos_profile_sensor_data)
        #  대회 MissionCommand 자리 — 어느 칸으로 갈지 밖에서 고른다
        #    파라미터 select 는 기본값이고, 이 토픽이 오면 그것을 쓴다
        self.create_subscription(Int32, '/tp_dock/select', self.cb_select, 10)
        self.pub_arr = self.create_publisher(PoseArray, '/tp_dock/stations', 10)
        self.pub_flat = self.create_publisher(Float32MultiArray,
                                              '/tp_dock/stations_flat', 10)
        self.pub_st = self.create_publisher(String, '/tp_dock/status', 10)
        self.pub_mk = self.create_publisher(MarkerArray, '/tp_dock/debug_markers', 10)

        #  대회 규약과 같은 꼴로 내는 토픽 — Simulink 가 이것만 읽는다
        #    대회는 px4_msgs/DockingTestParam 을 uORB 로 주고받았다 (ROS 블록이
        #    아니라 PX4 uORB Read 블록이었다). 필드 순서를 그대로 옮긴다
        #      [0] timestamp [us]  [1] psi_ned  [2] idx_ned_x  [3] idx_ned_y
        #      [4] wp_ned_x        [5] wp_ned_y
        #    psi_ned 는 베이 개구부가 향하는 NED 방위 [rad], idx 는 입구점,
        #    wp 는 approach_dist 만큼 앞에 둔 접근점. 전부 월드 NED [m]
        self.pub_dp = self.create_publisher(Float64MultiArray,
                                            '/tp_dock/docking_param', 10)
        self.create_timer(1.0 / P('publish_hz'), self.on_timer)
        self.get_logger().info(
            '기둥기반 검출 시작 - bin_w %.2f / pillar_tol %.2f / depth_min %.2f / 목표 칸 %d'
            % (P('bay.bin_w'), P('bay.pillar_tol'), P('bay.depth_min'), P('select')))

    # 입력 ---------------------------------------------------------------
    def cb_select(self, m):
        v = int(m.data)
        if 0 <= v < 3 and v != self.sel_cmd:
            self.sel_cmd = v
            self.get_logger().info('[SELECT] 칸 %d 로 바꿨다' % v)

    def cb_odom(self, m):
        q = m.pose.pose.orientation
        self.pose = (m.pose.pose.position.y, m.pose.pose.position.x, yaw_of(q))

    # 선체계(라이다) <-> 월드 NED 2D 변환 -------------------------------
    #   M = [[sy, cy], [cy, -sy]] 는 대칭이고 M^2 = I 라 같은 식이 역변환이다
    def _xy_mat(self):
        north, east, yaw = self.pose
        cy, sy = math.cos(yaw), math.sin(yaw)
        n0 = north + self.P('lidar_fwd') * sy
        e0 = east + self.P('lidar_fwd') * cy
        return n0, e0, cy, sy

    def b2w(self, d2):
        n0, e0, cy, sy = self._xy_mat()
        x, y = d2[:, 0], d2[:, 1]
        return np.column_stack((n0 + x * sy + y * cy, e0 + x * cy - y * sy))

    def w2b(self, w):
        n0, e0, cy, sy = self._xy_mat()
        dn, de = w[:, 0] - n0, w[:, 1] - e0
        return np.column_stack((dn * sy + de * cy, dn * cy - de * sy))

    def cb_cloud(self, m):
        P = self.P
        xyz = pointcloud2_to_xyz(m)
        d2 = remove_ground_to_2d(xyz, P('roi.z_min'), P('roi.z_max'),
                                 P('roi.x_min'), P('roi.x_max'),
                                 P('roi.y_abs_max'),
                                 P('ground.cell'), P('ground.z_wall_min'))
        self._nf = getattr(self, "_nf", 0) + 1
        if self._nf <= 3 or self._nf % 100 == 0:
            self.get_logger().info("frame %d: xyz %d -> ROI/ground %d, pose=%s"
                                   % (self._nf, len(xyz), len(d2), self.pose is not None))
        if len(d2) == 0:
            return
        if P('accum.enable'):
            world = P('accum.world') and self.pose is not None
            self.acc.add(self.b2w(d2) if world else d2)
            pts = self.acc.get()
            if world and len(pts):
                pts = self.w2b(pts)      # 검출은 선체계에서 한다 (대회와 같은 순서)
            if not self.acc.ready:
                self.status = 'ACCUM %d/%d' % (self.acc.count(),
                                               P('accum.target_pts'))
                self.pts2d = pts
                return
        else:
            pts = d2
        self.pts2d = pts
        if P("dump_npz") and not getattr(self, "_dumped", False):
            np.savez(P("dump_npz"), points=pts, pose=np.array(self.pose),
                     frame_id="lidar", frames=self._nf)
            self._dumped = True
            self.get_logger().info("덤프 %s (%d점)" % (P("dump_npz"), len(pts)))
        self.detect(pts)

    # 검출 (대회 find_bays_auto 와 같은 순서) -----------------------------
    def detect(self, pts):
        P = self.P
        bin_w = P('bay.bin_w')
        if len(pts) < P('bay.min_pts_per_bin') * 3:
            self.status = 'TOO FEW PTS'
            return
        rp, c, theta = rectify(pts)
        keep = wall_band_filter(rp, bin_w, P('bay.band_depth'))
        if keep.sum() >= P('bay.min_pts_per_bin') * 3:
            pts = pts[keep]
            rp, c, theta = rectify(pts)
        y_lo = float(rp[:, 1].min()) - bin_w
        y_hi = float(rp[:, 1].max()) + bin_w
        bays, prof = find_bays_pillars(
            rp, y_lo, y_hi, bin_w, P('bay.min_pts_per_bin'),
            P('bay.depth_min'), P('bay.width_min'), P('bay.width_max'),
            P('bay.approach_dist'),
            pillar_tol=P('bay.pillar_tol'),
            pillar_width_min=P('bay.pillar_width_min'),
            bridge_bins=P('bay.bridge_bins'))
        Rinv = np.array([[math.cos(-theta), -math.sin(-theta)],
                         [math.sin(-theta), math.cos(-theta)]])
        #  격벽 앞면 기준거리 = 입구면의 x (정렬 좌표계). 대회 함수를 그대로 쓴다
        xs_prof = np.asarray(prof[1], dtype=float)
        px = float(robust_pillar_baseline(xs_prof)) if len(xs_prof) >= 3 else None

        def back_to_orig(v):
            return (np.asarray(v, dtype=float) - c) @ Rinv.T + c

        for b in bays:
            #  psi 는 정렬 좌표계의 벽 법선(안쪽 방향) — theta 를 빼기 전에 쓴다
            nrm = np.array([math.cos(b['psi']), math.sin(b['psi'])])
            back_r = np.asarray(b['idx'], dtype=float)      # 안쪽 벽면
            if px is not None:
                b['depth'] = float(max(b['x_depth'] - px, 0.0))
                mouth_r = np.array([px, b['y_center']])
            else:
                b['depth'] = float('nan')
                mouth_r = back_r.copy()
            wp_r = mouth_r - P('bay.approach_dist') * nrm   # 입구 앞 접근점
            b['back'] = back_to_orig(back_r)
            b['idx'] = back_to_orig(mouth_r)                # 발행점 = 입구면
            b['wp'] = back_to_orig(wp_r)
            b['psi'] = float(b['psi'] - theta)
        self.bays = bays
        if len(bays) != 3 or self.pose is None:
            self.status = 'DETECTED %d/3' % len(bays)
            self.stable_count = 0
            self.locked = False
            self.lock_t0 = None
            return
        self.to_world(bays)

    # 선체계 -> 월드, 평활/안정/잠금 (대회 _smooth / _process_target 구조) --
    def to_world(self, bays):
        P = self.P
        north, east, yaw = self.pose
        cy, sy = math.cos(yaw), math.sin(yaw)
        n0 = north + P('lidar_fwd') * sy
        e0 = east + P('lidar_fwd') * cy
        raw = []
        def to_w(v):
            x, y = float(v[0]), float(v[1])
            return n0 + x * sy + y * cy, e0 + x * cy - y * sy

        for b in bays:
            n_i, e_i = to_w(b['idx'])                   # 입구면
            open_enu = wrap(yaw + b['psi'] + math.pi)   # 개구부가 향하는 방향
            #  접근 웨이포인트도 같은 변환으로 월드로 옮긴다 (대회 wp_ned_x/y)
            wn, we = to_w(b['wp'])
            bn, be = to_w(b.get('back', b['idx']))      # 안쪽 벽면
            raw.append((n_i, e_i, open_enu, float(b['width']), wn, we,
                        bn, be, float(b.get('depth', float('nan')))))
        raw.sort(key=lambda t: t[1])        # 서 -> 동

        sm = []
        for i, (n_i, e_i, a_i, w_i, wn, we, bn, be, dp_i) in enumerate(raw):
            self.hist[i].append((n_i, e_i, math.cos(a_i), math.sin(a_i),
                                 w_i, wn, we, bn, be, dp_i))
            H = np.array(self.hist[i])
            sm.append((H[:, 0].mean(), H[:, 1].mean(),
                       math.atan2(H[:, 3].mean(), H[:, 2].mean()), H[:, 4].mean(),
                       H[:, 5].mean(), H[:, 6].mean(),
                       H[:, 7].mean(), H[:, 8].mean(), H[:, 9].mean()))
        self.world = sm

        if self.last_sm is None:
            self.last_sm = sm
            self.stable_count = 1
            self.status = 'DETECTED 3/3'
            return
        pd = max(math.hypot(a[0] - b[0], a[1] - b[1])
                 for a, b in zip(sm, self.last_sm))
        ad = max(abs(wrap(a[2] - b[2])) for a, b in zip(sm, self.last_sm))
        self.last_sm = sm
        if pd < P('stable.pos_tol') and ad < math.radians(P('stable.psi_tol_deg')):
            self.stable_count += 1
        else:
            self.stable_count = 0
            self.locked = False
            self.lock_t0 = None
        if self.stable_count < P('stable.thresh'):
            self.status = 'STABLE %d/%d' % (self.stable_count, P('stable.thresh'))
            return
        now = self.get_clock().now().nanoseconds * 1e-9
        if self.lock_t0 is None:
            self.lock_t0 = now
        if not self.locked and now - self.lock_t0 >= P('stable.lock_duration'):
            self.locked = True
            self.get_logger().info('[LOCK] 세 칸 잠금')
            for i, S in enumerate(sm):
                n_i, e_i, a_i, w_i = S[0], S[1], S[2], S[3]
                az = (90.0 - math.degrees(a_i)) % 360.0
                self.get_logger().info(
                    '   칸%d  WP1 기준 입구 d북 %+6.2f  d동 %+6.2f m  '
                    '설치방향(개구부) %5.1f 도  폭 %.2f m  깊이 %.2f m'
                    % (i, n_i - P('wp1_north'), e_i - P('wp1_east'), az,
                       w_i, S[8]))
        self.status = 'LOCKED' if self.locked else 'STABLE'

    # 발행 ---------------------------------------------------------------
    def on_timer(self):
        P = self.P
        stamp = self.get_clock().now().to_msg()
        sel = self.sel_cmd if self.sel_cmd is not None else int(P('select'))

        st = String()
        st.data = self.status
        self.pub_st.publish(st)

        pa = PoseArray()
        pa.header.stamp = stamp
        pa.header.frame_id = 'wp1'
        fl = Float32MultiArray()
        # Float32MultiArray.data 는 array.array 라 += 리스트가 안 된다 -> 리스트로 모아 한 번에 대입
        flat = [1.0 if len(self.world) == 3 else 0.0,
                1.0 if self.locked else 0.0, float(sel)]
        for S in self.world:
            n_i, e_i, a_i, w_i = S[0], S[1], S[2], S[3]
            dN = n_i - P('wp1_north')
            dE = e_i - P('wp1_east')
            az = (90.0 - math.degrees(a_i)) % 360.0
            ps = Pose()
            ps.position.x, ps.position.y, ps.position.z = dN, dE, w_i
            ps.orientation.z = math.sin(a_i / 2.0)
            ps.orientation.w = math.cos(a_i / 2.0)
            pa.poses.append(ps)
            flat += [dN, dE, az, w_i, S[8]]
        while len(flat) < 18:
            flat.append(float('nan'))
        fl.data = [float(v) for v in flat]

        #  대회 규약 토픽 — 고른 칸 하나만, DockingTestParam 필드 순서대로
        #    세 칸이 다 잡히기 전에는 내지 않는다. 0 을 내면 Simulink 가 원점을
        #    목표로 삼아 출발한다 (대회 코드도 detect_on 으로 같은 것을 막았다)
        if len(self.world) == 3 and 0 <= sel < 3:
            S = self.world[sel]
            n_s, e_s, a_s, wn_s, we_s = S[0], S[1], S[2], S[4], S[5]
            dp = Float64MultiArray()
            dp.data = [float(self.get_clock().now().nanoseconds // 1000),
                       float(wrap(math.pi / 2.0 - a_s)),   # ENU 방위 -> NED 선수각
                       float(n_s), float(e_s),
                       float(wn_s), float(we_s)]
            self.pub_dp.publish(dp)
        self.pub_arr.publish(pa)
        self.pub_flat.publish(fl)

        self.pub_mk.publish(build_markers(
            stamp, P('viz.frame_id'), self.pts2d, self.bays,
            sel, self.status, locked=self.locked))


def main():
    rclpy.init()
    n = DockDetect()
    try:
        rclpy.spin(n)
    except KeyboardInterrupt:
        pass
    finally:
        n.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
