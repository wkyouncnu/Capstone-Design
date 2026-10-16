#!/usr/bin/env bash
# measure_bow.sh — 선수추진기의 +지령이 배를 어느 쪽으로 미는지 실제로 잰다 (6주차 2-4)
#
#   bash measure_bow.sh            # +500 N 을 8 초
#   bash measure_bow.sh 500 8      # 힘[N] 시간[s] 을 직접 주기
#   bash measure_bow.sh -500 8     # 부호를 바꿔 반대쪽도 확인
#
#   VRX 를 띄운 터미널과 다른 터미널에서 실행한다 (bash run_vrx_bow.sh 가 떠 있어야 한다).
#   재는 값 — 선체 고정 좌표계에서의 이동량
#     전진  : +앞,  횡     : +우현(NED +y)
#     요 변화 : +시계방향(NED +psi)
#   부호를 외우지 않고 이 측정으로 정한다. 강의자료의 표는 이 출력을 그대로 옮긴 것이다.

FORCE="${1:-500}"
SECS="${2:-8}"
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

# 시작 자리를 넓은 물로 옮긴다 — 스폰은 남쪽 해안에 붙어 있어 우현으로 밀면 얹힌다
# (to_open_water.sh 머리말, 2026-10-16). 스폰 자리 그대로 재려면 STAY=1 bash measure_bow.sh
[ -n "$STAY" ] || bash "$(dirname "${BASH_SOURCE[0]}")/to_open_water.sh" || exit 1

python3 - "$FORCE" "$SECS" <<'PY'
import math, sys, time
import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64
from nav_msgs.msg import Odometry

FORCE = float(sys.argv[1])
SECS  = float(sys.argv[2])
TOPIC = '/wamv/sensors/position/ground_truth_odometry'

def yaw_of(q):
    return math.atan2(2.0*(q.w*q.z + q.x*q.y), 1.0 - 2.0*(q.y*q.y + q.z*q.z))

class Probe(Node):
    def __init__(self):
        super().__init__('measure_bow')
        self.odom = None
        self.create_subscription(Odometry, TOPIC, self.cb, 10)
        self.pub = {n: self.create_publisher(Float64, f'/wamv/thrusters/{n}/thrust', 10)
                    for n in ('left', 'right', 'bow')}
    def cb(self, m):
        self.odom = m
    def send(self, bow):
        for n, p in self.pub.items():
            p.publish(Float64(data=float(bow if n == 'bow' else 0.0)))
    def pose(self):
        o = self.odom.pose.pose
        return o.position.x, o.position.y, yaw_of(o.orientation)

rclpy.init()
nd = Probe()

t0 = time.time()
while nd.odom is None and time.time() - t0 < 10.0:
    rclpy.spin_once(nd, timeout_sec=0.1)
if nd.odom is None:
    print(f'{TOPIC} 가 오지 않음 — VRX 가 떠 있는지, ROS_DOMAIN_ID 가 같은지 확인')
    raise SystemExit(1)

x0, y0, yaw0 = nd.pose()
print(f'지령      : 선수추진기 {FORCE:+.0f} N 을 {SECS:.0f} 초 (좌·우 추진기는 0 N)')
print(f'시작 위치 : ENU x={x0:8.3f}  y={y0:8.3f}   yaw={math.degrees(yaw0):7.2f} deg')

t0 = time.time()
while time.time() - t0 < SECS:
    nd.send(FORCE)
    rclpy.spin_once(nd, timeout_sec=0.05)
x1, y1, yaw1 = nd.pose()

t0 = time.time()                       # 추진기를 끄고 잠깐 더 돌려 0 지령이 들어가게 한다
while time.time() - t0 < 1.0:
    nd.send(0.0)
    rclpy.spin_once(nd, timeout_sec=0.05)

dx, dy = x1 - x0, y1 - y0
c, s = math.cos(yaw0), math.sin(yaw0)
fwd  =  c*dx + s*dy                    # 선체 x (앞)
port = -s*dx + c*dy                    # 선체 y_ENU (좌현)
stbd = -port                           # NED 의 +y
dpsi = -math.degrees(math.atan2(math.sin(yaw1 - yaw0), math.cos(yaw1 - yaw0)))   # NED psi = -yaw

print(f'끝 위치   : ENU x={x1:8.3f}  y={y1:8.3f}   yaw={math.degrees(yaw1):7.2f} deg')
print(f'선체 이동 : 전진 {fwd:+7.3f} m   횡(+우현) {stbd:+7.3f} m   요(+시계) {dpsi:+7.2f} deg')
side = '우현(NED +y)' if stbd*(1.0 if FORCE>0 else -1.0) > 0 else '좌현(NED -y)'
print(f'판정      : 선수추진기 +지령 -> {side} 로 밀린다   (요도 {"+시계" if dpsi*(1.0 if FORCE>0 else -1.0) > 0 else "-반시계"} 방향)')
if abs(dpsi) > 20.0:
    print('주의      : 좌·우 추진기로 요를 잡지 않았으므로 배가 크게 돌았다.')
    print('            위의 전진·횡 값은 방향 부호만 읽는다. 크기는 measure_sway.sh 로 잰다.')
nd.destroy_node()
rclpy.shutdown()
PY
