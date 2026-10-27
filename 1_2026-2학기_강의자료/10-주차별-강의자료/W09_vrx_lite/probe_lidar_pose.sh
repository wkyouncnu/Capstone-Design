#!/usr/bin/env bash
# probe_lidar_pose.sh — 라이다를 어느 높이에 달아야 배 자신이 안 찍히는가 (9주차 2-4)
#
#   bash probe_lidar_pose.sh              # z = 1.6 · 1.8 · 2.2 · 2.6 m 를 차례로 재 본다
#   bash probe_lidar_pose.sh 1.8 2.6      # 재 볼 높이를 직접 지정
#
#   왜 재는가
#     360 도 라이다를 배 위에 달면 광선 일부가 **자기 배**를 때린다. 그 값은 장애물이
#     아닌데 충돌회피 쪽은 장애물로 받는다 — 가만히 떠 있어도 회피 모드가 켜진 채로
#     있게 된다. 배의 외형은 앞 2.5 m · 뒤 2.4 m · 반폭 1.23 m 다 (충돌회피 코드의
#     HULL_X_MAX · HULL_X_MIN · HULL_HALF_WIDTH). 그 안쪽에서 들어오는 값이 곧 자기 배다.
#
#   무엇을 보는가 — 높이마다 네 숫자
#     자기배 %    선체 외형(앞 2.5 · 뒤 -2.4 · 반폭 1.23 m) 안에서 들어온 광선의 비율
#     수면 %      앞뒤 어느 쪽이든 5 m 넘는 거리에 한 구간으로 몰린 값 (평면 = 물)
#     쓸수있음    자기배도 수면도 아닌 값의 개수 — 진짜 장애물을 볼 여력
#     가장가까운  자기배를 뺀 최소 거리
#
#   한 높이에 2~3 분 걸린다. 화면 없이 돈다.

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash
: "${ROS_DOMAIN_ID:=7}"; export ROS_DOMAIN_ID

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORLD="${WORLD:-stationkeeping_task}"
ZS=("$@"); [ ${#ZS[@]} -eq 0 ] && ZS=(1.6 1.8 2.2 2.6)

ANALYZE='
import rclpy, numpy as np, os
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import LaserScan
HULL_X_MIN, HULL_X_MAX, HULL_HW = -2.4, 2.5, 1.23
rclpy.init(); n = Node("pose_probe"); got = []
q = QoSProfile(depth=1); q.reliability = ReliabilityPolicy.BEST_EFFORT
n.create_subscription(LaserScan, "/wamv/sensors/lidars/lidar_wamv_sensor/scan",
                      lambda m: got.append(m), q)
for _ in range(300):
    rclpy.spin_once(n, timeout_sec=0.1)
    if len(got) >= 3: break
if not got:
    print("  ?      ?      ?      ?   (/scan 을 못 받았다)")
else:
    m = got[-1]
    r = np.asarray(m.ranges, float)
    th = m.angle_min + np.arange(len(r)) * m.angle_increment
    ok = np.isfinite(r) & (r > 0.1) & (r < m.range_max)
    r, th = r[ok], th[ok]
    x, y = r*np.cos(th), r*np.sin(th)
    #  선체 외형 안쪽 = 자기 배
    self_hit = (x > HULL_X_MIN) & (x < HULL_X_MAX) & (np.abs(y) < HULL_HW)
    rest = r[~self_hit]
    #  5 m 밖에서 한 구간에 반 넘게 몰리면 평면 — 물이다
    water = 0
    if len(rest):
        far = rest[rest > 5.0]
        if len(far) > 5:
            h, e = np.histogram(far, bins=15)
            if h.max() > 0.5*len(far): water = h.max()
    usable = len(rest) - water
    nearest = rest.min() if len(rest) else float("nan")
    print(f"  {100*self_hit.sum()/len(r):5.0f}%  {100*water/max(len(r),1):5.0f}%"
          f"  {usable:6d}  {nearest:8.2f}")
rclpy.shutdown()
'

printf '%-7s %7s %6s %8s %9s\n' 높이z 자기배 수면 쓸수있음 가장가까운
echo "-------------------------------------------------"
for Z in "${ZS[@]}"; do
  bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1 || true
  sleep 2
  CA_LIDAR_Z="$Z" OUT="$HOME/capstone_ws/wamv/wamv_ca_probe.urdf" \
    bash "$HERE/make_wamv_ca.sh" lite >/dev/null 2>&1
  ros2 launch vrx_gz competition.launch.py world:="$WORLD" \
       urdf:="$HOME/capstone_ws/wamv/wamv_ca_probe.urdf" headless:=true \
       > /tmp/w09_pose_launch.log 2>&1 &
  LPID=$!
  for _ in $(seq 1 60); do
    ros2 topic list 2>/dev/null | grep -q lidar_wamv_sensor && break; sleep 2
  done
  gz topic -t /vrx/release -m gz.msgs.Empty -p '' 2>/dev/null || true
  sleep 8
  printf '%-7s' "$Z"
  python3 -c "$ANALYZE"
  kill $LPID 2>/dev/null || true
  sleep 2
done
bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1 || true
echo "-------------------------------------------------"
echo "자기배 % 가 0 에 가깝고 쓸수있음 이 큰 높이를 고른다."
echo "마스트 길이 = z - 1.2965 - 0.05 이므로 z 는 1.35 m 보다 커야 한다."
