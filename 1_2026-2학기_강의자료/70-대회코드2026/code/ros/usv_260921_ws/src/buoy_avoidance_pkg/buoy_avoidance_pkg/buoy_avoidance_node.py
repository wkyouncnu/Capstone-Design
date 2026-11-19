#!/usr/bin/env python3
"""buoy_avoidance_node.py — LiDAR 클러스터링 + 어안 카메라 색 판정 기반 구형 부표 수로 통과
─────────────────────────────────────────────────────────────────────────────
KABOAT 2026 부표 회피 (operation_mode 5). 빨강/초록 구형 부표가 두 줄로 만든 수로를 통과한다.

    /livox/lidar ─┐
                  ├─> [클러스터링 → 색 판정 → 트래킹 → 게이트 계획]   (라이다 콜백, 모드와 무관하게 항상)
    /image_raw  ──┘                     │ 최신 계획 (속도, 상대 방위각, 목표 유무)
    /usv/state/{heading,position_ned,goal_ned} ─┤
    /fmu/out/operation_mode ──> [_loop 20 Hz, operation_mode gating] ─> /vfh/command, /vfh/oa_flag
                                                                       (→ px4_cmd_pub → /fmu/in/*)

collision_avoidance_node_livox.py (auto_usv_pkg) 와 같은 방식으로 제어 명령을 낸다 (2026-10-23~).
PX4 토픽에 직접 쓰지 않고 /vfh/command 와 /vfh/oa_flag 를 발행하며, px4_cmd_pub
(px4_mission_msg_pub_node.py) 이 이를 /fmu/in/{offboard_control_mode,trajectory_setpoint} 로 바꾼다.
    /vfh/command   linear.x = 속도 [m/s], angular.z = 절대 NED 방위각 [rad]
                   (= pi2pi(heading_ned - 상대 방위각), 상대 방위각은 라이다 프레임 좌 +)
    /vfh/oa_flag   True = PX4 가 /vfh/command 를 따른다
발행 충돌은 operation_mode 로 막는다: operation_mode == active_mode(기본 5) 일 때만 발행하고,
그 외 모드이거나 모드 미수신이면 침묵한다. 충돌회피 노드(3)와 /vfh/* 를 공유하지만 서로 다른
모드에서만 말하므로 섞이지 않는다 (예전 vfh_command_bridge 의 로직을 이 노드로 옮긴 것).

mode 5 에서의 판단 (collision_avoidance_node_livox 와 같은 구조, 2026-10-24~):
    상황                                        명령                      oa_flag
    게이트 추종 (planner gate/single_row/hold)  게이트 목표 방향          True   (충돌회피의 Avoidance)
    진입 후 아직 부표 못 봄 (approach_timeout 안) 경유점 방향 직진        True   (APPROACH, 2026-10-25~)
    부표 없음 + 목표 있음 (진입 직후, 통과 후)   경유점 방향 직진          False  (충돌회피의 Straight)
    부표 없음 + 목표 없음                        속도 0, 현재 헤딩         False  (충돌회피의 HOLD)
    계획/헤딩 stale                              속도 0, 현재 헤딩         False  (충돌회피의 stale)
  oa_flag=False 는 "Simulink 가 WP 추종을 맡는다" 는 뜻이다. 그래서 mode 5 경유점이지만 부표가
  아직 안 보이거나 이미 다 지나간 경우에도 배가 경유점으로 계속 가서 다음 모드로 넘어간다.
  (예전엔 게이트를 본 뒤 2 s 놓치면 속도 0 + False 로 래치했는데, 진입 직후엔 판정이 없어 속도 0
   + True 로 멈춰 있었다.)
  게이트 깜빡임은 planner 의 hold_sec(직전 목표 유지 시간)가 흡수한다.
  APPROACH (2026-10-25~): Simulink 는 mode 5 에서 oa_flag=False 를 받으면 mode 1 로 돌아간다.
  그래서 부표가 인식되기 전에 mode 5 로 들어오면 첫 주기의 False 로 곧바로 튕겨 나갔다
  (exp1016 재생에서 진입 0.05 s 만에 5→1). 진입 후 부표(planner != stop)를 한 번도 못 본 동안은
  경유점 쪽으로 가면서 True 를 유지하고, approach_timeout_sec 이 지나도 못 보면 GOAL/HOLD(False) 로 넘긴다.

디버그 토픽 (모드와 무관하게 발행):
    /buoy/gate_visible 폭 검사를 통과한 red-green 게이트 쌍이 이번 프레임에 있는지
    /buoy/markers, /buoy/red, /buoy/green, /buoy/overlay_image/compressed

설계 메모 (exp1016 bag 분석 결과):
  - 위치는 전부 LiDAR 로 정한다. 카메라는 클러스터 중심을 투영한 작은 패치의 색만 본다.
    → 카메라 내부/외부 파라미터 오차가 위치 오차로 번지지 않는다.
  - 이미지-라이다 짝짓기는 "라이다 도착 시점의 가장 최근 이미지"(수신 시각 기준).
    usb_cam header stamp 가 수신 시각보다 ~0.69 s 앞서 찍혀 header 기준 동기화는 틀어진다.
  - /camera_info 는 구독하지 않는다 (exp1016 에선 구 핀홀 값 fx≈746 이 나왔음).
    카메라 모델은 파라미터(cam_*)로만 받는다.
  - 인지/계획 주기는 라이다(10 Hz)를 따른다. 라이다가 끊기면 계획이 갱신되지 않아서
    _loop 가 plan_timeout_sec 뒤 stale 로 판단해 정지한다.
─────────────────────────────────────────────────────────────────────────────
"""
import array
import math
import time

import cv2
import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy

from geometry_msgs.msg import Pose, PoseArray, Point, Twist
from sensor_msgs.msg import CompressedImage, Image, PointCloud2
from std_msgs.msg import Bool, Float32
from px4_msgs.msg import OperationMode
from visualization_msgs.msg import Marker, MarkerArray

from buoy_avoidance_pkg import core
from buoy_avoidance_pkg.ros_conv import cloud_to_xyz, image_to_bgr
from buoy_avoidance_pkg.viz import draw_bev, draw_overlay

_MARKER_RGB = {core.RED: (1.0, 0.1, 0.1), core.GREEN: (0.1, 0.8, 0.1), core.UNKNOWN: (0.8, 0.2, 0.8)}


def pi2pi(a: float) -> float:
    """각도를 (-pi, pi] 로 정규화."""
    return (a + math.pi) % (2.0 * math.pi) - math.pi


_NODE_PARAMS = dict(
    lidar_topic='/livox/lidar',
    image_topic='/image_raw',
    # 제어 명령 (collision_avoidance_node_livox 와 같은 규약, operation_mode gating)
    rate_hz=20.0,                 # /vfh/command 발행 주기 (충돌회피 노드와 동일)
    active_mode=5,                # 이 operation_mode 일 때만 /vfh/* 발행
    plan_timeout_sec=0.5,         # 계획(라이다 처리)이 이보다 오래되면 정지
    heading_timeout_sec=0.5,
    position_timeout_sec=0.5,     # position_ned 가 이보다 오래되면 경유점 직진 대신 HOLD
    goal_timeout_sec=0.0,         # goal_ned 는 WP 바뀔 때만 오는 이벤트 토픽 → 0 = 무제한 (충돌회피와 동일)
    goal_speed=0.8,               # 부표가 없을 때 경유점 직진 속도 [m/s]
    approach_timeout_sec=15.0,    # mode 5 진입 후 부표를 못 본 채 True 를 유지하는 최대 시간 [s]
    max_image_age_sec=0.3,
    publish_overlay=True,
    overlay_every_n=1,
    sensor_qos_reliable=True,
    overlay_jpeg_quality=80,
    publish_overlay_raw=False,
    # 어안 카메라 모델 (config/buoy_params.yaml 참고)
    cam_width=640, cam_height=480,
    cam_fx=239.08, cam_fy=239.08, cam_cx=315.77, cam_cy=233.47,
    cam_dist=[-0.0180, -0.0151, 0.0, 0.0],
    cam_rvec_correction=[-0.0496, 0.0356, 0.0149],
    cam_tvec=[0.038, 0.125, 0.285],
    cam_valid_radius_px=330.0,
    red_hsv_flat=[0, 90, 60, 9, 255, 255, 166, 90, 60, 179, 255, 255],
    green_hsv_flat=[38, 60, 35, 88, 255, 255],
)


class BuoyAvoidanceNode(Node):

    def __init__(self):
        super().__init__('buoy_avoidance')

        defaults = {}
        defaults.update(core.DEFAULT_CLUSTER_PARAMS)
        defaults.update({k: v for k, v in core.DEFAULT_COLOR_PARAMS.items()
                         if k not in ('red_hsv_ranges', 'green_hsv_ranges')})
        defaults.update(core.DEFAULT_TRACKER_PARAMS)
        defaults.update(core.DEFAULT_PLANNER_PARAMS)
        defaults.update(_NODE_PARAMS)
        P = {}
        for name, val in defaults.items():
            if isinstance(val, int) and not isinstance(val, bool):
                val = int(val)
            self.declare_parameter(name, val)
            P[name] = self.get_parameter(name).value
        self.P = P

        self.cluster_p = {k: P[k] for k in core.DEFAULT_CLUSTER_PARAMS}
        self.color_p = {k: P[k] for k in core.DEFAULT_COLOR_PARAMS if k not in ('red_hsv_ranges', 'green_hsv_ranges')}
        self.color_p['red_hsv_ranges'] = np.array(P['red_hsv_flat'], dtype=int).reshape(-1, 2, 3).tolist()
        self.color_p['green_hsv_ranges'] = np.array(P['green_hsv_flat'], dtype=int).reshape(-1, 2, 3).tolist()
        self.camera = core.FisheyeCamera(
            P['cam_fx'], P['cam_fy'], P['cam_cx'], P['cam_cy'], P['cam_dist'],
            P['cam_rvec_correction'], P['cam_tvec'], P['cam_width'], P['cam_height'],
            P['cam_valid_radius_px'])
        self.tracker = core.BuoyTracker({k: P[k] for k in core.DEFAULT_TRACKER_PARAMS})
        self.planner = core.GatePlanner({k: P[k] for k in core.DEFAULT_PLANNER_PARAMS})

        self.last_image = None
        self.last_image_t = None
        self.frame_count = 0
        self.proc_ms_ema = None

        # 최신 계획 (라이다 콜백이 쓰고 _loop 가 읽는다 — 둘 다 단일 스레드 executor 라 lock 불필요)
        self._plan_speed = 0.0
        self._plan_bearing = 0.0           # 라이다 프레임 상대 방위각 [rad], 좌 +
        self._plan_mode = 'none'           # planner: gate / single_row / hold / stop
        self._t_plan: int | None = None    # 마지막 계획 시각 [ns]
        self._heading: float | None = None   # /usv/state/heading, NED [rad, CW]
        self._t_heading: int | None = None
        self._pos_ned: np.ndarray | None = None
        self._t_pos: int | None = None
        self._goal_ned: np.ndarray | None = None
        self._t_goal: int | None = None
        # operation_mode (Simulink 발행): 1=WP추종 2=loiter 3=충돌회피 4=docking 5=부표
        #   None = 아직 수신 안 됨 → gating 통과 안 함(안전측)
        self._op_mode: int | None = None
        self._state = None                 # 직전 판단 (로그용: 상태가 바뀔 때만 INFO)
        self._t_enter: int | None = None   # 이번 mode 5 진입 시각 [ns]
        self._seen_buoy = False            # 이번 mode 5 진입 후 부표 추종(planner != stop)을 한 번이라도 했는지

        self._pub_cmd = self.create_publisher(Twist, '/vfh/command', 10)
        self._pub_flag = self.create_publisher(Bool, '/vfh/oa_flag', 10)
        self.pub_gate = self.create_publisher(Bool, '/buoy/gate_visible', 10)
        self.pub_markers = self.create_publisher(MarkerArray, '/buoy/markers', 10)
        self.pub_red = self.create_publisher(PoseArray, '/buoy/red', 10)
        self.pub_green = self.create_publisher(PoseArray, '/buoy/green', 10)
        # 오버레이는 JPEG(/buoy/overlay_image/compressed, ~100 KB)로 보낸다. bgr8 원본(1120x480 = 1.6 MB)은
        # DDS 가 UDP 조각 수백 개로 쪼개서, best-effort 구독(rviz/rqt)에선 조각 하나만 잃어도 프레임이
        # 통째로 버려진다 (실측: 10 Hz 발행 → best-effort 0.5 Hz, reliable 7.5 Hz 수신).
        self.pub_overlay_jpeg = self.create_publisher(CompressedImage, '/buoy/overlay_image/compressed', 1)
        self.pub_overlay = (self.create_publisher(Image, '/buoy/overlay_image', 1)
                            if P['publish_overlay_raw'] else None)

        # 센서 구독은 기본 reliable. 이미지(0.6 MB)/점군(0.5 MB)은 UDP 조각으로 쪼개지는데, best-effort 면
        # 조각 하나만 잃어도 프레임이 통째로 버려진다 (실측: best-effort 로 받으면 이미지가 0.3 s 이상
        # 끊기는 구간이 잦아 색 판정이 빠졌다). usb_cam / livox 드라이버 / bag play 는 모두 reliable 로 발행한다.
        # 발행 쪽이 best-effort 인 드라이버를 쓰면 sensor_qos_reliable:=false 로 (reliable 구독은 연결 안 됨).
        sensor_qos = QoSProfile(
            depth=2, history=HistoryPolicy.KEEP_LAST,
            reliability=ReliabilityPolicy.RELIABLE if P['sensor_qos_reliable'] else ReliabilityPolicy.BEST_EFFORT)
        self.create_subscription(Image, P['image_topic'], self.image_callback, sensor_qos)
        self.create_subscription(PointCloud2, P['lidar_topic'], self.lidar_callback, sensor_qos)

        # 상태 토픽은 collision_avoidance_node_livox 와 같은 best-effort QoS
        state_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )
        self.create_subscription(Float32, '/usv/state/heading', self._cb_heading, state_qos)
        self.create_subscription(Point, '/usv/state/position_ned', self._cb_pos, state_qos)
        self.create_subscription(Point, '/usv/state/goal_ned', self._cb_goal, state_qos)
        self.create_subscription(OperationMode, '/fmu/out/operation_mode', self._cb_op_mode, state_qos)

        self.create_timer(1.0 / P['rate_hz'], self._loop)

        self.get_logger().info(
            f"buoy_avoidance started: lidar={P['lidar_topic']} image={P['image_topic']} "
            f"red_side={P['red_side']} gate_width=[{P['gate_min_width_m']}, {P['gate_max_width_m']}] m "
            f"speed={P['default_speed']} m/s | /vfh/command @ {P['rate_hz']:.0f} Hz, "
            f"active_mode={P['active_mode']}")

    def now_sec(self):
        return self.get_clock().now().nanoseconds * 1e-9

    def _now_ns(self) -> int:
        return self.get_clock().now().nanoseconds

    def _cb_heading(self, msg: Float32):
        self._heading = float(msg.data)
        self._t_heading = self._now_ns()

    def _cb_pos(self, msg: Point):
        self._pos_ned = np.array([msg.x, msg.y])
        self._t_pos = self._now_ns()

    def _cb_goal(self, msg: Point):
        self._goal_ned = np.array([msg.x, msg.y])
        self._t_goal = self._now_ns()

    def _cb_op_mode(self, msg: OperationMode):
        self._op_mode = round(float(msg.operation_mode))

    def _stale(self, t: int | None, now: int, timeout: float) -> bool:
        """수신 시각이 없거나 timeout 초과면 True."""
        return t is None or (now - t) * 1e-9 > timeout

    # ── 제어 명령 루프 (collision_avoidance_node_livox._loop 와 같은 구조) ──────

    def _loop(self):
        P = self.P
        # ── operation_mode gating ─────────────────────────────────────────────
        # operation_mode == active_mode(기본 5=부표) 일 때만 /vfh/* 를 발행한다.
        # 그 외 모드이거나 모드 수신 전(None)이면 '침묵' — 충돌회피(3)/도킹(4) 등
        # 다른 유도의 명령과 섞이지 않는다.
        if self._op_mode != P['active_mode']:
            self._state = None
            self._t_enter = None
            self._seen_buoy = False
            self.get_logger().info(
                f"operation_mode={self._op_mode} (≠{P['active_mode']}) — 대기(침묵).",
                throttle_duration_sec=5.0)
            return

        if self._heading is None:
            self.get_logger().warn(
                '/usv/state/heading 미수신 → 절대 yaw 계산 불가, 발행 보류.', throttle_duration_sec=2.0)
            return

        # ── staleness 페일세이프 ─────────────────────────────────────────────
        # 계획(라이다 처리) 또는 헤딩이 끊기면 옛 데이터로 주행하지 않고 정지.
        # oa_flag=False 로 WP 추종을 Simulink 에 넘긴다 (충돌회피 노드와 동일).
        now = self._now_ns()
        if self._t_enter is None:
            self._t_enter = now
        if (self._stale(self._t_plan, now, P['plan_timeout_sec'])
                or self._stale(self._t_heading, now, P['heading_timeout_sec'])):
            self._publish('STALE', 0.0, self._heading, False)
            self.get_logger().warn('입력 stale (계획/헤딩) — 정지 유지.', throttle_duration_sec=2.0)
            return

        # ── BUOY MODE: 게이트(또는 한쪽 줄) 추종 ─────────────────────────────
        # planner 가 목표를 갖고 있거나 hold_sec 안에 직전 목표를 유지 중이면 우리가 조종한다.
        if self._plan_mode != 'stop':
            # 상대 방위각(좌 +) → 절대 NED 방위각 (NED 는 CW 양수라 부호 반전)
            yaw_ned = pi2pi(self._heading - self._plan_bearing)
            self._seen_buoy = True
            self._publish('BUOY', self._plan_speed, yaw_ned, True)
            return

        # ── 부표 없음 (진입 후 아직 못 봄 / 게이트를 다 지난 뒤) ──────────────────
        # goal staleness — GOAL_TIMEOUT<=0 이면 강등하지 않는다 (goal_ned 는 이벤트 토픽)
        if (self._goal_ned is not None and P['goal_timeout_sec'] > 0.0
                and self._stale(self._t_goal, now, P['goal_timeout_sec'])):
            self.get_logger().warn('goal stale — HOLD 로 강등.', throttle_duration_sec=2.0)
            self._goal_ned = None
            self._t_goal = None

        goal_ok = self._goal_ned is not None and not self._stale(self._t_pos, now, P['position_timeout_sec'])

        # ── APPROACH: 진입 후 아직 부표를 못 봄 → 경유점 쪽으로 가며 True 유지 ──────
        # 여기서 False 를 내면 Simulink 가 '통과 완료' 로 보고 곧바로 mode 1 로 돌아간다.
        if not self._seen_buoy and (now - self._t_enter) * 1e-9 <= P['approach_timeout_sec']:
            if goal_ok:
                diff = self._goal_ned - self._pos_ned
                self._publish('APPROACH', P['goal_speed'], math.atan2(diff[1], diff[0]), True)
            else:
                self._publish('APPROACH', 0.0, self._heading, True)
            return

        # ── GOAL MODE: 경유점 방향 직진, WP 추종은 Simulink 에 넘김 ─────────────
        if goal_ok:
            diff = self._goal_ned - self._pos_ned
            goal_yaw_ned = math.atan2(diff[1], diff[0])
            self._publish('GOAL', P['goal_speed'], goal_yaw_ned, False)
            return

        # ── HOLD MODE: 목표/위치 없음 → 정지 ──────────────────────────────────
        self._publish('HOLD', 0.0, self._heading, False)

    def _publish(self, state: str, speed: float, yaw_ned: float, oa_flag: bool):
        self._pub_cmd.publish(self._twist(speed, yaw_ned))
        self._pub_flag.publish(self._bool(oa_flag))
        if state != self._state:
            self.get_logger().info(
                f"mode {self.P['active_mode']}: {self._state} -> {state} "
                f"(planner={self._plan_mode}, oa_flag={oa_flag})")
            self._state = state
        self.get_logger().info(
            f"VFH {state:5s} | speed={speed:.2f} yaw={math.degrees(yaw_ned):+.1f}deg "
            f"hdg={math.degrees(self._heading):+.1f}deg oa_flag={oa_flag}",
            throttle_duration_sec=2.0)

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

    def image_callback(self, msg):
        # 변환은 라이다 콜백에서 필요할 때만 (30 Hz 전부 변환하면 CPU 낭비)
        self.last_image = msg
        self.last_image_t = self.now_sec()

    def lidar_callback(self, msg):
        t_wall = time.perf_counter()
        t = self.now_sec()
        P = self.P

        bgr = None
        if self.last_image is not None and t - self.last_image_t <= P['max_image_age_sec']:
            bgr = image_to_bgr(self.last_image)
            if bgr is None:
                self.get_logger().error(
                    f"지원하지 않는 이미지 인코딩: {self.last_image.encoding}", throttle_duration_sec=5.0)
        else:
            self.get_logger().warn(
                f"{P['image_topic']} 없음/오래됨 — 색 판정 생략 (트랙에 누적된 색만 사용).",
                throttle_duration_sec=2.0)

        cloud = cloud_to_xyz(msg)
        clusters = core.extract_buoy_clusters(cloud, self.cluster_p)
        cls = core.classify_clusters(bgr, clusters, self.camera, self.color_p)
        self.tracker.update(clusters, [c[0] for c in cls], t)
        tracks = self.tracker.confirmed()
        buoys = [(x, y, c) for _, x, y, c, _ in tracks]
        # 통과한 게이트 기억에는 NED 위치/헤딩이 필요하다. 끊겼으면 전방 콘 제한만 적용.
        now_ns = self._now_ns()
        pose = None
        if (self._pos_ned is not None and self._heading is not None
                and not self._stale(self._t_pos, now_ns, P['position_timeout_sec'])
                and not self._stale(self._t_heading, now_ns, P['heading_timeout_sec'])):
            pose = (float(self._pos_ned[0]), float(self._pos_ned[1]), self._heading)
        plan = self.planner.plan(buoys, t, pose)

        # 제어 명령은 _loop 가 operation_mode 를 보고 발행한다 — 여기선 최신 계획만 갱신
        self._plan_speed = float(plan['speed'])
        self._plan_bearing = float(plan['bearing'])
        self._plan_mode = plan['mode']
        self._t_plan = self._now_ns()
        self.pub_gate.publish(Bool(data=plan['gate_visible']))

        self.publish_poses(msg.header, tracks)
        self.publish_markers(msg.header, tracks, plan)
        self.frame_count += 1
        if P['publish_overlay'] and bgr is not None and self.frame_count % max(1, P['overlay_every_n']) == 0:
            ov = draw_overlay(bgr, clusters, cls, self.camera, plan)
            bev = draw_bev(tracks, plan, size=ov.shape[0], half_range=12.0)
            frame = np.ascontiguousarray(np.hstack([ov, bev]))
            ok, jpg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, int(P['overlay_jpeg_quality'])])
            if ok:
                cimg = CompressedImage()
                cimg.header = msg.header
                cimg.format = 'bgr8; jpeg compressed bgr8'
                cimg.data = array.array('B', jpg.tobytes())
                self.pub_overlay_jpeg.publish(cimg)
            if self.pub_overlay is not None:
                out = Image()
                out.header = msg.header
                out.height, out.width = frame.shape[:2]
                out.encoding = 'bgr8'
                out.step = frame.shape[1] * 3
                # bytes 를 그대로 넣으면 rclpy 가 원소마다 범위 검사를 해서 ~60 ms 걸린다 (array 는 ~1 ms)
                out.data = array.array('B', frame.tobytes())
                self.pub_overlay.publish(out)

        ms = (time.perf_counter() - t_wall) * 1e3
        self.proc_ms_ema = ms if self.proc_ms_ema is None else 0.9 * self.proc_ms_ema + 0.1 * ms
        n_r = sum(1 for b in buoys if b[2] == core.RED)
        n_g = sum(1 for b in buoys if b[2] == core.GREEN)
        side = plan['red_left']
        self.get_logger().info(
            f"{plan['mode']:10s} | clusters={len(clusters)} tracks R{n_r}/G{n_g}/?{len(buoys) - n_r - n_g} "
            f"gates={len(plan['gates'])} passed={plan['n_passed']}{'' if pose else '(no pose)'} "
            f"red={'?' if side is None else ('L' if side else 'R')} "
            f"-> v={plan['speed']:.2f} brg={math.degrees(plan['bearing']):+.1f}deg "
            f"({self.proc_ms_ema:.0f} ms)",
            throttle_duration_sec=1.0)

    def publish_poses(self, header, tracks):
        for color, pub in ((core.RED, self.pub_red), (core.GREEN, self.pub_green)):
            pa = PoseArray()
            pa.header = header
            for _, x, y, c, _ in tracks:
                if c == color:
                    pose = Pose()
                    pose.position.x = float(x)
                    pose.position.y = float(y)
                    pose.orientation.w = 1.0
                    pa.poses.append(pose)
            pub.publish(pa)

    def publish_markers(self, header, tracks, plan):
        ma = MarkerArray()
        clear = Marker()
        clear.header = header
        clear.action = Marker.DELETEALL
        ma.markers.append(clear)
        mid = 0
        for _, x, y, c, _ in tracks:
            m = Marker()
            m.header = header
            m.ns = 'buoys'
            m.id = mid
            mid += 1
            m.type = Marker.SPHERE
            m.action = Marker.ADD
            m.pose.position.x = float(x)
            m.pose.position.y = float(y)
            m.pose.position.z = 0.15
            m.pose.orientation.w = 1.0
            d = 2.0 * self.P['buoy_radius_m']
            m.scale.x = m.scale.y = m.scale.z = d
            m.color.r, m.color.g, m.color.b = _MARKER_RGB[c]
            m.color.a = 0.8
            ma.markers.append(m)
        if plan['gates']:
            m = Marker()
            m.header = header
            m.ns = 'gates'
            m.id = mid
            mid += 1
            m.type = Marker.LINE_LIST
            m.action = Marker.ADD
            m.pose.orientation.w = 1.0
            m.scale.x = 0.05
            m.color.r = m.color.g = m.color.b = 0.3
            m.color.a = 1.0
            for g in plan['gates']:
                m.points.append(Point(x=float(g[2][0]), y=float(g[2][1]), z=0.2))
                m.points.append(Point(x=float(g[3][0]), y=float(g[3][1]), z=0.2))
            ma.markers.append(m)
        m = Marker()
        m.header = header
        m.ns = 'command'
        m.id = mid
        m.type = Marker.ARROW
        m.action = Marker.ADD
        L = 1.0 + 3.0 * plan['speed']
        m.points.append(Point(x=0.0, y=0.0, z=0.3))
        m.points.append(Point(x=L * math.cos(plan['bearing']), y=L * math.sin(plan['bearing']), z=0.3))
        m.scale.x, m.scale.y, m.scale.z = 0.08, 0.2, 0.2
        m.color.r, m.color.g, m.color.b, m.color.a = 0.1, 0.3, 1.0, 1.0
        ma.markers.append(m)
        self.pub_markers.publish(ma)


def main(args=None):
    rclpy.init(args=args)
    node = BuoyAvoidanceNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
