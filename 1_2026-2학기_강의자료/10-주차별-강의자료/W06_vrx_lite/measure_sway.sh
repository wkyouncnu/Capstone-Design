#!/usr/bin/env bash
# measure_sway.sh — 추력배분으로 만든 pure sway 가 Gazebo 에서 되는지 잰다 (6주차 2-5)
#
#   bash measure_sway.sh              # Y = +250 N 을 10 초
#   bash measure_sway.sh 250 10       # 횡력[N] 시간[s]
#   bash measure_sway.sh -250 10      # 반대쪽
#
#   measure_bow.sh 는 선수추진기만 켜므로 배가 크게 돌아 버린다. 여기서는
#   요 지령을 0 으로 두고 배분행렬이 좌·우 추진기에 반대 부호를 주게 한다.
#
#     tau = [X; Y; N] = [0; Y; 0]
#     T   = [ 1       1      0  ]        b  = half_beam = 1.027135 m
#           [ 0       0      1  ]        l3 = 선수추진기 x 위치 = 0.75 m
#           [ b      -b      l3 ]
#     풀면   F_B = Y,   F_L = -l3*Y/(2b),   F_R = +l3*Y/(2b)
#
#   되는 것 : 횡(+우현) 이 Y 부호대로 커지고, 요 변화와 전진이 거의 0 으로 남는다.
#   강의자료의 표는 이 출력을 그대로 옮긴 것이다.

Y="${1:-250}"
SECS="${2:-10}"
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

# 시작 자리를 넓은 물로 옮긴다 — 스폰은 남쪽 해안에 붙어 있어 우현으로 밀면 얹힌다
# (to_open_water.sh 머리말, 2026-10-16). 스폰 자리 그대로 재려면 STAY=1 bash measure_sway.sh
[ -n "$STAY" ] || bash "$(dirname "${BASH_SOURCE[0]}")/to_open_water.sh" || exit 1

python3 - "$Y" "$SECS" <<'PY'
import math, sys, time
import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64
from nav_msgs.msg import Odometry

Y     = float(sys.argv[1])
SECS  = float(sys.argv[2])
B     = 1.027135          # half_beam [m]
L3    = 0.75              # 선수추진기 x 위치 [m]
TOPIC = '/wamv/sensors/position/ground_truth_odometry'

FB = Y
FL = -L3*Y/(2.0*B)
FR = +L3*Y/(2.0*B)

def yaw_of(q):
    return math.atan2(2.0*(q.w*q.z + q.x*q.y), 1.0 - 2.0*(q.y*q.y + q.z*q.z))

class Probe(Node):
    def __init__(self):
        super().__init__('measure_sway')
        self.odom = None
        self.create_subscription(Odometry, TOPIC, self.cb, 10)
        self.pub = {n: self.create_publisher(Float64, f'/wamv/thrusters/{n}/thrust', 10)
                    for n in ('left', 'right', 'bow')}
    def cb(self, m):
        self.odom = m
    def send(self, fl, fr, fb):
        self.pub['left'].publish(Float64(data=float(fl)))
        self.pub['right'].publish(Float64(data=float(fr)))
        self.pub['bow'].publish(Float64(data=float(fb)))
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
print(f'지령      : tau = [0, {Y:+.0f}, 0]  ->  F_L={FL:+7.2f}  F_R={FR:+7.2f}  F_B={FB:+7.2f} N,  {SECS:.0f} 초')
print(f'시작 위치 : ENU x={x0:8.3f}  y={y0:8.3f}   yaw={math.degrees(yaw0):7.2f} deg')

t0 = time.time()
while time.time() - t0 < SECS:
    nd.send(FL, FR, FB)
    rclpy.spin_once(nd, timeout_sec=0.05)
x1, y1, yaw1 = nd.pose()

t0 = time.time()                       # 추진기를 끄고 잠깐 더 돌려 0 지령이 들어가게 한다
while time.time() - t0 < 1.0:
    nd.send(0.0, 0.0, 0.0)
    rclpy.spin_once(nd, timeout_sec=0.05)

dx, dy = x1 - x0, y1 - y0
c, s = math.cos(yaw0), math.sin(yaw0)
fwd  =  c*dx + s*dy                    # 선체 x (앞)
stbd = -(-s*dx + c*dy)                 # NED 의 +y (우현)
dpsi = -math.degrees(math.atan2(math.sin(yaw1 - yaw0), math.cos(yaw1 - yaw0)))   # NED psi = -yaw

print(f'끝 위치   : ENU x={x1:8.3f}  y={y1:8.3f}   yaw={math.degrees(yaw1):7.2f} deg')
print(f'선체 이동 : 전진 {fwd:+7.3f} m   횡(+우현) {stbd:+7.3f} m   요(+시계) {dpsi:+7.2f} deg')
print(f'평균 횡속 : {stbd/SECS:+6.3f} m/s')
ok_side = (stbd > 0) == (Y > 0)
ok_yaw  = abs(dpsi) < 15.0
ok_fwd  = abs(fwd) < 0.3*abs(stbd) + 0.5
print(f'판정      : 횡 방향 {"맞음" if ok_side else "틀림"} · 요 유지 {"맞음" if ok_yaw else "틀림"}'
      f' · 전진 억제 {"맞음" if ok_fwd else "틀림"}')
print('            세 가지가 모두 맞으면 배분행렬의 부호가 Gazebo 와 일치한다')
nd.destroy_node()
rclpy.shutdown()
PY
