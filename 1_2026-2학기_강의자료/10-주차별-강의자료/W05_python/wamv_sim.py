#!/usr/bin/env python3
"""wamv_sim — VRX 없이 도는 WAM-V (5주차 E-4)

VRX 와 **같은 토픽 이름 · 같은 메시지 형식**으로 GPS · IMU 를 내고 추력을 받는다.
그래서 에이전트가 만든 제어 노드를 한 글자도 바꾸지 않고 먼저 여기에 물려 볼 수 있다.

    터미널 1   python3 wamv_sim.py                 # VRX 대신
    터미널 2   ros2 run team_usv waypoint_pid       # 학생 노드 그대로

안에 든 것
    운동모델   3주차 1-8 절 — Simulink 의 EOM 블록과 같은 식, 같은 계수
    센서 모델  4주차 1-5 절 — GPS 20 Hz (안테나 x_b = -0.85 m), IMU 100 Hz (자이로 잡음)

토픽
    구독  /wamv/thrusters/left/thrust    std_msgs/Float64   [N]
          /wamv/thrusters/right/thrust   std_msgs/Float64   [N]
    발행  /wamv/sensors/gps/gps/fix      sensor_msgs/NavSatFix  20 Hz
          /wamv/sensors/imu/imu/data     sensor_msgs/Imu        100 Hz  (ENU, 쿼터니언 x y z w)
          /wamv_sim/truth                geometry_msgs/Pose2D   20 Hz   (NED 참값 x 북, y 동, theta = psi)

좌표 — 본 과목 규약
    NED 위치 x (북), y (동), 선수각 psi (북에서 시계 +). 코드 이름 x_n, y_n
    ROS 메시지는 ENU 로 낸다 (VRX 와 같게). 변환은 3주차 1-5 절

파라미터 (ros2 run 이 아니라 python3 로 돌리므로 --ros-args -p 로 준다)
    psi0_deg   초기 선수각 [deg]   기본 0 (북쪽)
    noise      자이로 잡음 켜기    기본 True
    rate_hz    적분 주기 [Hz]      기본 100

    python3 wamv_sim.py --ros-args -p psi0_deg:=90.0
"""
import math
import random

import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64
from sensor_msgs.msg import NavSatFix, Imu
from geometry_msgs.msg import Pose2D

# ---- 3주차 1-8 절: VRX 플러그인 파일의 계수 --------------------------------
M_USV = 211.0            # 질량 [kg]  = 180 + 2x15 + 2x0.5
IZZ = 653.0              # 요 관성 [kg m^2]
XU, XUU = 100.0, 150.0   # 전후 항력
YV, YVV = 100.0, 100.0   # 좌우 항력
NR, NRR = 800.0, 800.0   # 요 항력
B_HALF = 1.027135        # 추진기 좌우 반폭 [m]
F_MAX = 2353.6           # VRX 추진기 명령 한계 [N] (wamv_gazebo_thruster_config.xacro)

# ---- 4주차 1-5 절: 센서 설정 ----------------------------------------------
GPS_HZ, IMU_HZ = 20, 100
GPS_XB, GPS_YB = -0.85, 0.0          # 안테나 위치 (선체 축 FRD) [m]
GYRO_STD, GYRO_BIAS = 0.009, 0.00075  # [rad/s]
LAT0, LON0, ALT0 = -33.72276870341191, 150.67399057896623, 1.183941401541233  # 3주차 기준점


def eom(s, fl, fr):
    """3주차 1-8 절의 EOM. s = [u, v, r, x_n, y_n, psi] -> ds/dt"""
    u, v, r, _, _, psi = s
    X = fl + fr
    N = (fl - fr) * B_HALF                # 요 모멘트 (위치가 아님)
    du = (X - (XU + XUU * abs(u)) * u) / M_USV + v * r
    dv = (-(YV + YVV * abs(v)) * v) / M_USV - u * r
    dr = (N - (NR + NRR * abs(r)) * r) / IZZ
    return [du, dv, dr,
            u * math.cos(psi) - v * math.sin(psi),
            u * math.sin(psi) + v * math.cos(psi),
            r]


def rk4(s, fl, fr, h):
    k1 = eom(s, fl, fr)
    k2 = eom([a + 0.5 * h * b for a, b in zip(s, k1)], fl, fr)
    k3 = eom([a + 0.5 * h * b for a, b in zip(s, k2)], fl, fr)
    k4 = eom([a + h * b for a, b in zip(s, k3)], fl, fr)
    return [a + h / 6.0 * (b + 2 * c + 2 * d + e) for a, b, c, d, e in zip(s, k1, k2, k3, k4)]


class WamvSim(Node):
    def __init__(self):
        super().__init__('wamv_sim')
        self.declare_parameter('psi0_deg', 0.0)
        self.declare_parameter('noise', True)
        self.declare_parameter('rate_hz', 100)
        psi0 = math.radians(self.get_parameter('psi0_deg').value)
        self.noise = bool(self.get_parameter('noise').value)
        self.rate = int(self.get_parameter('rate_hz').value)
        self.h = 1.0 / self.rate

        self.s = [0.0, 0.0, 0.0, 0.0, 0.0, psi0]     # [u v r x_n y_n psi]
        self.fl = 0.0
        self.fr = 0.0
        self.k = 0
        self.bias = GYRO_BIAS

        a, e2 = 6378137.0, 6.69437999014e-3          # WGS84
        s2 = math.sin(math.radians(LAT0)) ** 2
        self.Rm = a * (1 - e2) / (1 - e2 * s2) ** 1.5
        self.Rn = a / math.sqrt(1 - e2 * s2)

        self.create_subscription(Float64, '/wamv/thrusters/left/thrust', self.on_left, 10)
        self.create_subscription(Float64, '/wamv/thrusters/right/thrust', self.on_right, 10)
        self.pub_gps = self.create_publisher(NavSatFix, '/wamv/sensors/gps/gps/fix', 10)
        self.pub_imu = self.create_publisher(Imu, '/wamv/sensors/imu/imu/data', 10)
        self.pub_truth = self.create_publisher(Pose2D, '/wamv_sim/truth', 10)
        self.create_timer(self.h, self.step)
        self.get_logger().info(
            f'wamv_sim 시작 — 운동모델 {self.rate} Hz, GPS {GPS_HZ} Hz, IMU {IMU_HZ} Hz, '
            f'초기 선수각 {math.degrees(psi0):.1f} deg, 자이로 잡음 {"켬" if self.noise else "끔"}')

    def on_left(self, msg):
        self.fl = max(-F_MAX, min(F_MAX, msg.data))

    def on_right(self, msg):
        self.fr = max(-F_MAX, min(F_MAX, msg.data))

    def step(self):
        self.s = rk4(self.s, self.fl, self.fr, self.h)
        self.s[5] = math.atan2(math.sin(self.s[5]), math.cos(self.s[5]))
        self.k += 1
        now = self.get_clock().now().to_msg()
        if self.k % (self.rate // IMU_HZ) == 0:
            self.publish_imu(now)
        if self.k % (self.rate // GPS_HZ) == 0:
            self.publish_gps(now)
            u, v, r, x_n, y_n, psi = self.s
            t = Pose2D(x=x_n, y=y_n, theta=psi)
            self.pub_truth.publish(t)

    def publish_gps(self, stamp):
        u, v, r, x_n, y_n, psi = self.s
        # 4주차 1-5: 안테나 위치 = 원점 + 선체 오프셋을 NED 로 돌린 것
        xa = x_n + GPS_XB * math.cos(psi) - GPS_YB * math.sin(psi)
        ya = y_n + GPS_XB * math.sin(psi) + GPS_YB * math.cos(psi)
        m = NavSatFix()
        m.header.stamp = stamp
        m.header.frame_id = 'wamv/wamv/gps_wamv_link'
        m.latitude = LAT0 + math.degrees(xa / self.Rm)
        m.longitude = LON0 + math.degrees(ya / (self.Rn * math.cos(math.radians(LAT0))))
        m.altitude = ALT0
        self.pub_gps.publish(m)

    def publish_imu(self, stamp):
        u, v, r, x_n, y_n, psi = self.s
        yaw = math.pi / 2 - psi                       # NED 선수각 -> ENU yaw
        m = Imu()
        m.header.stamp = stamp
        m.header.frame_id = 'wamv/wamv/imu_wamv_link'
        m.orientation.z = math.sin(yaw / 2)
        m.orientation.w = math.cos(yaw / 2)
        n = random.gauss(0.0, GYRO_STD) if self.noise else 0.0
        m.angular_velocity.z = -r + (self.bias + n if self.noise else 0.0)   # r_ENU = -r_NED
        self.pub_imu.publish(m)


def main():
    rclpy.init()
    node = WamvSim()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
