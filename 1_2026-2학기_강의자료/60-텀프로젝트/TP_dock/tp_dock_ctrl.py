#!/usr/bin/env python3
"""
tp_dock_ctrl.py — WP1 위치유지 + 순수 횡이동(crabbing) 도킹 진입

출처
────────────────────────────────────────────────────────────────────────
제어 구조와 게인은 대회 코드의 위치제어를 그대로 가져온다.
원본: 70-대회코드2026/code/ros/yaml/otter_2fixed_docking_mission.yaml
  SURGE_VEL_P 100.0 / SURGE_VEL_I 0.0 / SURGE_VEL_D 0.0
  HEADING_P    40.0 / HEADING_D    25.0
  U_SETPOINT    1.0 / DOCKING_RADIUS 0.5 / U_STOP_THRESH 0.05
→ 서지는 속도 P 제어, 선수각은 P-D 제어(미분항은 각속도 r 에 직접).
  대회 기체는 Otter(소형), 본 월드는 WAM-V(약 180 kg 급)라 게인의 절대값은
  스케일이 다르다. 구조와 비율은 유지하고 크기만 파라미터로 노출함.

바꾼 것 — 토픽과 추력 배분뿐
  · 상태 입력 : /fmu/out/* → /wamv/sensors/position/ground_truth_odometry
  · 추력 출력 : PX4 actuator → /wamv/thrusters/{left,right,bow}/{thrust,pos}
  · Otter 2-fixed(선미 2기 고정) → WAM-V 3기(선미 2기 회전 + 선수 1기 횡방향)

추력 배분 — urdf 실측 기하
────────────────────────────────────────────────────────────────────────
wamv_term_lite.urdf 의 조인트 origin 에서 직접 읽은 값:
  선미 좌현 : xyz (-2.373776, +1.027135)   회전 조인트 (pos)
  선미 우현 : xyz (-2.373776, -1.027135)   회전 조인트 (pos)
  선수      : xyz (+0.750000,  0.000000)   rpy yaw = -90 deg
              → 선수 추진기는 애초에 옆을 향해 달려 있다.
                pos=0 에서 추력 +T 가 선체 -y(우현) 방향 힘이 된다.
                모멘트 N = 0.75 * F_y = -0.75 * T   (레버 0.75 m)
                대회 자료의 `F_by = N_cmd / 0.75` 가 이 레버다.

모드 1 — HOLD / ALIGN (선미 pos = 0)
  힘   X = T_L + T_R
  힘   Y = -T_bow
  모멘트 N = 1.027135 * (T_R - T_L) - 0.75 * T_bow
  → 3식 3미지수로 정확히 풀린다 (의사역행렬 불필요)
       T_bow  = -Y
       T_R-T_L = (N - 0.75 * Y) / 1.027135
       T_R+T_L = X

모드 2 — SWAY (순수 횡이동, crabbing)
  선미 2기를 고정각 ±delta 로 틀어 횡력만 만들고 요 모멘트는 0 이 되게 한다.
    delta = 23.396 deg,  기당 크기 = 1.25907 * |Y_d|
    좌현 pos = -delta, 우현 pos = +delta,  T_L = -1.25907*Y, T_R = +1.25907*Y
    → 역추력이 필수다 (한 기는 반드시 음수)
  이 배치는 요 권한이 0 이라 선수각 유지는 선수 추진기가 전담한다.
    T_bow = -N_cmd / 0.75
  실측 상한: 횡력 397 N → 약 1.49 m/s

상태기계
  HOLD  : WP1 위치유지, 선수각 hold_yaw (기본 90 deg = 북향)
  ALIGN : 선택한 칸의 진입 대기점으로 이동 + 선수각을 부두 벽 방향으로 90 deg 회두
  SWAY  : 서지 0, 순수 횡이동으로 칸 안으로 진입
  DONE  : 추력 0

발행 토픽
  /wamv/thrusters/{left,right,bow}/thrust   std_msgs/Float64  [N]
  /wamv/thrusters/{left,right}/pos          std_msgs/Float64  [rad]
  /tp_dock/ctrl        std_msgs/String        상태 문자열
  /tp_dock/ctrl_flat   std_msgs/Float32MultiArray
      [mode, sel, n, e, yawdeg, u, v, r, e_surge, e_sway, e_yawdeg,
       X, Y, N, T_L, T_R, T_bow, posdeg]  (MATLAB GUI 가 읽는 토픽)
"""
import math
import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from nav_msgs.msg import Odometry
from std_msgs.msg import Float64, String, Float32MultiArray

ODOM = '/wamv/sensors/position/ground_truth_odometry'
STATIONS = '/tp_dock/stations_flat'

# urdf 실측 기하 [m]
LY = 1.027135          # 선미 추진기 y 오프셋 (반 간격)
BOW_X = 0.750          # 선수 추진기 x 레버
# crabbing 배분 (대회/W09 실측값)
DELTA = math.radians(23.396)
KCRAB = 1.25907

MODES = ['HOLD', 'ALIGN', 'SWAY', 'DONE']


def yaw_of(q):
    return math.atan2(2.0 * (q.w * q.z + q.x * q.y),
                      1.0 - 2.0 * (q.y * q.y + q.z * q.z))


def wrap(a):
    return (a + math.pi) % (2.0 * math.pi) - math.pi


def clamp(v, lim):
    return max(-lim, min(lim, v))


class DockCtrl(Node):
    def __init__(self):
        super().__init__('tp_dock_ctrl')
        d = lambda k, v: self.declare_parameter(k, v)

        # --- 위치 ---
        d('wp1_north', 10.0)
        d('wp1_east', 0.0)
        d('hold_yaw_deg', 90.0)        # ENU (0=동, 90=북)
        d('select', 1)                 # 0=서, 1=중앙, 2=동
        d('mode', 'hold')              # hold | enter
        # 진입 기하 — 세 칸의 입구는 북 22.5 (make_haeyang_world.py DOCK_Y_IN)
        d('mouth_north', 22.5)
        d('standoff', 6.0)             # 입구에서 남쪽으로 떨어진 대기 거리
        d('enter_north', 25.5)         # 진입 완료 목표 (입구 + 3.0)

        # --- 대회 게인 (otter_2fixed_docking_mission.yaml 구조) ---
        d('surge_vel_p', 100.0)        # SURGE_VEL_P
        d('heading_p', 40.0)           # HEADING_P
        d('heading_d', 25.0)           # HEADING_D
        d('u_setpoint', 1.0)           # U_SETPOINT (전진 속도 상한)
        d('docking_radius', 0.5)       # DOCKING_RADIUS
        d('u_stop_thresh', 0.05)       # U_STOP_THRESH
        # 위치 -> 속도 외측 루프 (대회는 WP 추종기에 있던 부분)
        d('pos_p', 0.35)               # 서지 위치 P [ (m/s) / m ]
        d('sway_vel_p', 120.0)         # 횡방향 속도 P
        d('sway_pos_p', 0.30)          # 횡방향 위치 P
        d('v_setpoint', 0.6)           # 횡이동 속도 상한 [m/s]

        # --- 한계 ---
        d('thrust_max', 500.0)         # 기당 추력 상한 [N]
        d('align_yaw_tol_deg', 5.0)
        d('align_pos_tol', 1.5)
        d('enter_tol', 0.8)
        d('ctrl_hz', 20.0)

        self.P = lambda k: self.get_parameter(k).value

        self.pose = None               # (n, e, yaw)
        self.vel = (0.0, 0.0, 0.0)     # (u, v, r) 선체계
        self.st = None                 # (dN, dE, az_deg, w) x3, 잠금 시
        self.locked = False
        self.state = 'HOLD'
        self.t_state = self.get_clock().now()
        self.last = [0.0] * 7

        self.create_subscription(Odometry, ODOM, self.cb_odom,
                                 qos_profile_sensor_data)
        self.create_subscription(Float32MultiArray, STATIONS, self.cb_st, 10)

        mk = lambda t: self.create_publisher(Float64, t, 10)
        self.p_tl = mk('/wamv/thrusters/left/thrust')
        self.p_tr = mk('/wamv/thrusters/right/thrust')
        self.p_tb = mk('/wamv/thrusters/bow/thrust')
        self.p_pl = mk('/wamv/thrusters/left/pos')
        self.p_pr = mk('/wamv/thrusters/right/pos')
        self.pub_s = self.create_publisher(String, '/tp_dock/ctrl', 10)
        self.pub_f = self.create_publisher(Float32MultiArray,
                                           '/tp_dock/ctrl_flat', 10)

        self.create_timer(1.0 / self.P('ctrl_hz'), self.on_timer)
        self.get_logger().info(
            '제어 시작 - mode %s / select %d / 대회게인 surgeP %.0f headP %.0f headD %.0f'
            % (self.P('mode'), self.P('select'), self.P('surge_vel_p'),
               self.P('heading_p'), self.P('heading_d')))

    # ---------------------------------------------------------------- 입력
    def cb_odom(self, m):
        p = m.pose.pose.position
        yaw = yaw_of(m.pose.pose.orientation)
        # ENU: x=동, y=북
        self.pose = (p.y, p.x, yaw)
        # 월드 선속도를 선체계로 (u=전진, v=좌현)
        vx, vy = m.twist.twist.linear.x, m.twist.twist.linear.y
        c, s = math.cos(yaw), math.sin(yaw)
        self.vel = (vx * c + vy * s, -vx * s + vy * c, m.twist.twist.angular.z)

    def cb_st(self, m):
        dv = list(m.data)
        if len(dv) < 15:
            return
        self.locked = dv[1] > 0.5
        if dv[0] > 0.5:
            self.st = [(dv[3 + 4 * i], dv[4 + 4 * i],
                        dv[5 + 4 * i], dv[6 + 4 * i]) for i in range(3)]

    # ------------------------------------------------------------ 추력 배분
    def send(self, X, Y, N, crab):
        """crab=False: 선미 pos=0, 3식 3미지수.  crab=True: 고정각 ±delta."""
        lim = self.P('thrust_max')
        if crab:
            tl = clamp(-KCRAB * Y, lim)
            tr = clamp(+KCRAB * Y, lim)
            tb = clamp(-N / BOW_X, lim)
            pl, pr = -DELTA, +DELTA
        else:
            tb = clamp(-Y, lim)
            diff = (N - BOW_X * Y) / LY    # N = LY*(T_R-T_L) - 0.75*T_bow, T_bow=-Y
            tr = clamp((X + diff) / 2.0, lim)
            tl = clamp((X - diff) / 2.0, lim)
            pl = pr = 0.0
        for pub, v in ((self.p_tl, tl), (self.p_tr, tr), (self.p_tb, tb),
                       (self.p_pl, pl), (self.p_pr, pr)):
            msg = Float64()
            msg.data = float(v)
            pub.publish(msg)
        self.last = [X, Y, N, tl, tr, tb, math.degrees(pr)]

    def stop(self):
        self.send(0.0, 0.0, 0.0, False)

    # ------------------------------------------------- 공통 제어기 (대회 구조)
    def heading_moment(self, yaw_ref):
        """HEADING_P / HEADING_D — 미분항은 각속도 r 에 직접 (대회와 동일)."""
        _, _, yaw = self.pose
        e = wrap(yaw_ref - yaw)
        r = self.vel[2]
        return self.P('heading_p') * e - self.P('heading_d') * r, e

    def surge_force(self, e_surge):
        """위치 P -> 속도 지령 -> SURGE_VEL_P (대회 캐스케이드)."""
        u_ref = clamp(self.P('pos_p') * e_surge, self.P('u_setpoint'))
        return self.P('surge_vel_p') * (u_ref - self.vel[0]), u_ref

    def sway_force(self, e_sway):
        v_ref = clamp(self.P('sway_pos_p') * e_sway, self.P('v_setpoint'))
        return self.P('sway_vel_p') * (v_ref - self.vel[1]), v_ref

    # --------------------------------------------------------------- 상태기계
    def body_err(self, n_t, e_t):
        """목표점까지의 오차를 선체계 (전진, 좌현) 으로."""
        n, e, yaw = self.pose
        dn, de = n_t - n, e_t - e
        c, s = math.cos(yaw), math.sin(yaw)
        # ENU yaw: 선수 방향 = (동 cos, 북 sin)
        fwd = dn * s + de * c
        port = dn * c - de * s
        return fwd, port

    def target_station(self):
        """선택한 칸의 (입구 북, 동, 부두 벽 방향 yaw)."""
        sel = int(self.P('select'))
        e_t = 0.0
        if self.st is not None:
            e_t = self.P('wp1_east') + self.st[sel][1]
        # 부두 벽은 동서로 뻗는다 -> 벽 방향 선수각은 동(0) 또는 서(180).
        # 현재 선수각에서 가까운 쪽을 고른다 (회두량 최소).
        yaw = self.pose[2]
        yaw_ref = 0.0 if abs(wrap(0.0 - yaw)) <= abs(wrap(math.pi - yaw)) else math.pi
        return e_t, yaw_ref

    def on_timer(self):
        if self.pose is None:
            self.pub_s.publish(String(data='WAIT ODOM'))
            return
        n, e, yaw = self.pose
        mode = str(self.P('mode'))

        if mode == 'hold' or self.state == 'HOLD':
            if mode == 'enter' and self.locked:
                self.state = 'ALIGN'
            else:
                yaw_ref = math.radians(self.P('hold_yaw_deg'))
                fwd, port = self.body_err(self.P('wp1_north'), self.P('wp1_east'))
                X, _ = self.surge_force(fwd)
                Y, _ = self.sway_force(port)
                N, eyaw = self.heading_moment(yaw_ref)
                self.send(X, Y, N, False)
                self.publish_state('HOLD', fwd, port, eyaw)
                return

        e_t, yaw_ref = self.target_station()

        if self.state == 'ALIGN':
            n_t = self.P('mouth_north') - self.P('standoff')
            fwd, port = self.body_err(n_t, e_t)
            X, _ = self.surge_force(fwd)
            Y, _ = self.sway_force(port)
            N, eyaw = self.heading_moment(yaw_ref)
            self.send(X, Y, N, False)
            self.publish_state('ALIGN', fwd, port, eyaw)
            if (abs(eyaw) < math.radians(self.P('align_yaw_tol_deg'))
                    and math.hypot(n_t - n, e_t - e) < self.P('align_pos_tol')):
                self.state = 'SWAY'
                self.get_logger().info(
                    '[ALIGN 완료] 북 %.2f 동 %.2f 선수각 %.1f -> 순수 횡이동 시작'
                    % (n, e, math.degrees(yaw)))
            return

        if self.state == 'SWAY':
            # 순수 횡이동: 서지 지령 없음. 횡방향만 제어.
            n_t = self.P('enter_north')
            fwd, port = self.body_err(n_t, e_t)
            Y, _ = self.sway_force(port)
            N, eyaw = self.heading_moment(yaw_ref)
            self.send(0.0, Y, N, True)
            self.publish_state('SWAY', fwd, port, eyaw)
            if abs(port) < self.P('enter_tol'):
                self.state = 'DONE'
                self.get_logger().info(
                    '[진입 완료] 칸 %d  북 %.2f 동 %.2f 선수각 %.1f  횡오차 %.2f m'
                    % (int(self.P('select')), n, e, math.degrees(yaw), port))
            return

        self.stop()
        self.publish_state('DONE', 0.0, 0.0, 0.0)

    def publish_state(self, name, fwd, port, eyaw):
        n, e, yaw = self.pose
        u, v, r = self.vel
        self.pub_s.publish(String(
            data='%s sel%d  e_fwd %+.2f e_lat %+.2f e_yaw %+.1f'
                 % (name, int(self.P('select')), fwd, port, math.degrees(eyaw))))
        fl = Float32MultiArray()
        fl.data = [float(x) for x in
                   [MODES.index(name), int(self.P('select')), n, e,
                    math.degrees(yaw), u, v, r, fwd, port,
                    math.degrees(eyaw)] + self.last]
        self.pub_f.publish(fl)


def main():
    rclpy.init()
    nd = DockCtrl()
    try:
        rclpy.spin(nd)
    except KeyboardInterrupt:
        pass
    finally:
        nd.stop()
        nd.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
