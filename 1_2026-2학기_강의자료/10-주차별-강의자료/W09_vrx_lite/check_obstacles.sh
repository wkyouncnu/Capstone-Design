#!/usr/bin/env bash
# check_obstacles.sh — 라이다에 **장애물이 실제로 들어오는지** 숫자로 확인한다 (9주차 2-5)
#
#   bash check_obstacles.sh          # lite 판, 40 초
#   bash check_obstacles.sh full 30  # 판과 시간을 바꿔서
#
#   왜 이것이 따로 필요한가
#     probe_lidar.sh 는 **가만히 서서** 한 장을 본다. 가만히 있으면 주위가 비어 있어
#     "값이 25 개 들어왔다" 정도만 보이고, 그 25 개가 멀리 있는 부두인지 장애물인지
#     알 수 없다. 회피가 되려면 **다가갈수록 거리가 줄어드는 것**이 보여야 한다.
#     그래서 이 판은 배를 앞으로 밀면서 1 초마다 가장 가까운 값을 적는다.
#
#   읽는 법 — 가장가까운 이 40 m 에서 10 m 로 **단조롭게 줄면** 성공이다.
#     줄지 않으면 셋 중 하나다 : 배가 안 움직임(/vrx/release 빠짐) · 앞이 비어 있음 ·
#     라이다가 자기 배만 봄(그러면 가장가까운 이 처음부터 2 m 아래로 고정된다).
#
#   Rviz 로 같은 것을 눈으로 보려면 (10주차 2-3-7 의 절차)
#     bash run_vrx_ca.sh                                   # 창 있는 판으로 띄우고
#     rviz2 -d w09_ca.rviz                                 # 다른 터미널에서
#   Fixed Frame 은 w09_ca.rviz 안에 wamv/wamv/base_link 로 박아 두었다.
#   Rviz2 기본값 map 은 이 세계에 없는 좌표계라 그냥 두면 전부 Error 로 뜬다.

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash
: "${ROS_DOMAIN_ID:=7}"; export ROS_DOMAIN_ID

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADE="${1:-lite}"
SECS="${2:-40}"
WORLD="${WORLD:-stationkeeping_task}"
U="$HOME/capstone_ws/wamv/wamv_ca_${GRADE}.urdf"

[ -f "$U" ] || bash "$HERE/make_wamv_ca.sh" "$GRADE"

bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1 || true
sleep 2
echo "== $GRADE 판으로 띄운다 (화면 없이), $SECS 초 동안 앞으로 민다 =="
ros2 launch vrx_gz competition.launch.py world:="$WORLD" \
     urdf:="$U" headless:=true > /tmp/w09_obs_launch.log 2>&1 &
LPID=$!
trap 'kill $LPID 2>/dev/null; bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1' EXIT

for _ in $(seq 1 60); do
  ros2 topic list 2>/dev/null | grep -q lidar_wamv_sensor && break
  sleep 2
done
gz topic -t /vrx/release -m gz.msgs.Empty -p '' 2>/dev/null || true
sleep 5

SECS="$SECS" python3 - <<'PY'
import os, math, rclpy, numpy as np
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import LaserScan
from geometry_msgs.msg import PoseStamped
from std_msgs.msg import Float64

SECS = float(os.environ.get('SECS', '40'))
BASE = '/wamv/sensors/lidars/lidar_wamv_sensor'
#  자기 배를 걸러내는 상자 — 회피 코드가 쓰는 선체 치수와 같은 값이다
HULL_X_MIN, HULL_X_MAX, HULL_HW = -2.4, 2.5, 1.23

rclpy.init()
n = Node('check_obstacles')
best = QoSProfile(depth=1); best.reliability = ReliabilityPolicy.BEST_EFFORT

box = {'scan': None, 'pose': None}
n.create_subscription(LaserScan, BASE + '/scan', lambda m: box.__setitem__('scan', m), best)
n.create_subscription(PoseStamped, '/wamv/gps_pose', lambda m: box.__setitem__('pose', m), best)
pubs = [n.create_publisher(Float64, f'/wamv/thrusters/{s}/thrust', 10) for s in ('left', 'right')]

print()
print('   초   앞으로간거리   40m안에들어온값  가장가까운   그방향')
print('  ---------------------------------------------------------------')
p0 = None
t_end = n.get_clock().now().nanoseconds * 1e-9 + SECS
t_next = 0.0
while rclpy.ok():
    t = n.get_clock().now().nanoseconds * 1e-9
    if t > t_end:
        break
    for p in pubs:                       # 앞으로만 민다 — 좌우 같은 힘이라 직진
        p.publish(Float64(data=600.0))
    rclpy.spin_once(n, timeout_sec=0.05)
    if t < t_next or box['scan'] is None:
        continue
    t_next = t + 2.0

    m = box['scan']
    r = np.asarray(m.ranges, float)
    th = m.angle_min + np.arange(len(r)) * m.angle_increment
    ok = np.isfinite(r) & (r > 0.2) & (r < m.range_max)
    r, th = r[ok], th[ok]
    x, y = r * np.cos(th), r * np.sin(th)
    self_hit = (x > HULL_X_MIN) & (x < HULL_X_MAX) & (np.abs(y) < HULL_HW)
    r, th = r[~self_hit], th[~self_hit]

    d = float('nan')
    if box['pose'] is not None:
        q = box['pose'].pose.position
        if p0 is None:
            p0 = (q.x, q.y)
        d = math.hypot(q.x - p0[0], q.y - p0[1])

    near = r < 40.0
    if near.any():
        i = np.argmin(r[near])
        #  ROS 는 반시계가 +, 우리는 시계가 + 라 부호를 뒤집어 적는다 (9주차 3-5)
        print(f'  {SECS-(t_end-t):5.0f}   {d:9.1f} m   {near.sum():12d}   '
              f'{r[near][i]:8.1f} m   {-math.degrees(th[near][i]):+6.0f} deg')
    else:
        print(f'  {SECS-(t_end-t):5.0f}   {d:9.1f} m   {0:12d}          -        -')

for p in pubs:
    p.publish(Float64(data=0.0))
print()
print('  가장가까운 이 줄어들면 라이다가 장애물을 물고 있는 것이다.')
print('  처음부터 2 m 아래로 고정이면 그것은 장애물이 아니라 자기 배다.')
rclpy.shutdown()
PY
