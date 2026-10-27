#!/usr/bin/env bash
# probe_lidar.sh — 라이다가 실제로 무엇을 보는지 확인한다 (9주차 2-4)
#
#   bash probe_lidar.sh            # lite 판으로 띄워서 토픽 · 한 장의 내용을 찍고 끈다
#   bash probe_lidar.sh ultralite  # 판을 바꿔서
#
#   무엇을 보는가
#     1. 라이다가 내는 ROS 2 토픽이 무엇무엇인지 (scan 과 points 는 다른 토픽이다)
#     2. /scan 의 머리글 — 광선 몇 개를 어느 각도 범위로 쏘는지
#     3. /scan 의 거리값 분포 — **값이 한 거리에 몰려 있는지**가 핵심이다.
#        몰려 있으면 그것은 장애물이 아니라 평면이다. 둘 중 하나를 의심한다.
#        (ㄱ) 수면 — z=1.9 m 라이다의 가장 아래 광선(-15 deg)은 1.9/tan15 = 7.1 m 앞
#             수면과 만난다. 물에 맞으면 장애물이 없어도 7.1 m 고리가 생긴다.
#        (ㄴ) 자기 배 — 0.35~2.3 m 에 몰리면 이쪽이다. 라이다가 너무 낮다는 뜻으로,
#             실제로 z=1.75 이하에서 값의 82% 가 이것이었다. 그래서 1.9 로 올렸다.
#     4. PointCloud2 한 장의 크기 — Rviz 에서 볼 것과 같은 자료다
#
#   끝나면 스스로 끈다. 중간에 멈추려면 Ctrl+C 한 뒤 bash ../W03_vrx_lite/stop_vrx.sh

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash
: "${ROS_DOMAIN_ID:=7}"; export ROS_DOMAIN_ID

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADE="${1:-lite}"
WORLD="${WORLD:-stationkeeping_task}"
U="$HOME/capstone_ws/wamv/wamv_ca_${GRADE}.urdf"
BASE=/wamv/sensors/lidars/lidar_wamv_sensor

[ -f "$U" ] || bash "$HERE/make_wamv_ca.sh" "$GRADE"

bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1 || true
sleep 2
echo "== $GRADE 판으로 띄운다 (화면 없이) =="
ros2 launch vrx_gz competition.launch.py world:="$WORLD" \
     urdf:="$U" headless:=true > /tmp/w09_probe_launch.log 2>&1 &
LPID=$!
trap 'kill $LPID 2>/dev/null; bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1' EXIT

for _ in $(seq 1 60); do
  ros2 topic list 2>/dev/null | grep -q lidar_wamv_sensor && break
  sleep 2
done
# 배를 풀어 준다 — 이것을 빼면 배가 묶인 채로 있다 (3주차 2-4)
gz topic -t /vrx/release -m gz.msgs.Empty -p '' 2>/dev/null || true
sleep 8

echo; echo "== 라이다가 내는 ROS 2 토픽 =="
for t in $(ros2 topic list | grep -i lidar); do
  printf '  %-62s %s\n' "$t" "$(ros2 topic type "$t" 2>/dev/null)"
done

echo; echo "== /scan 머리글 — 광선 수와 각도 범위 =="
ros2 topic echo --once --no-arr "$BASE/scan" 2>&1 \
  | grep -E 'angle_|time_increment|scan_time|range_m|frame_id' | sed 's/^/  /'

echo; echo "== /scan 거리값 — 물 표면이 찍히는지 =="
python3 - <<'PY'
import rclpy, numpy as np
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import LaserScan
rclpy.init()
n = Node('probe')
got = []
qos = QoSProfile(depth=1); qos.reliability = ReliabilityPolicy.BEST_EFFORT
n.create_subscription(LaserScan, '/wamv/sensors/lidars/lidar_wamv_sensor/scan',
                      lambda m: got.append(m), qos)
for _ in range(200):
    rclpy.spin_once(n, timeout_sec=0.1)
    if got: break
if not got:
    print('  /scan 을 못 받았다 — 토픽 이름이나 브리지를 확인')
else:
    m = got[-1]
    r = np.asarray(m.ranges, float)
    fin = np.isfinite(r) & (r > 0.1) & (r < m.range_max)
    print(f'  광선 {len(r)} 개 중 값이 들어온 것 {fin.sum()} 개 '
          f'({100*fin.sum()/len(r):.0f}%)')
    if fin.any():
        v = r[fin]
        print(f'  거리 최소 {v.min():.2f} m,  중앙 {np.median(v):.2f} m,  최대 {v.max():.2f} m')
        # 한 거리에 값이 몰려 있으면 그것은 장애물이 아니라 평면(물 · 지면)이다
        h, e = np.histogram(v, bins=20)
        top = h.argmax()
        print(f'  가장 많이 몰린 거리 구간 {e[top]:.2f}~{e[top+1]:.2f} m 에 {h[top]} 개 '
              f'({100*h[top]/fin.sum():.0f}%)')
        print(f'  참고: z=1.9 m 라이다의 -15 deg 광선은 7.09 m 앞 수면과 만난다')
        print(f'        0.35~2.3 m 에 몰려 있으면 그것은 자기 배다 — 라이다가 낮다는 뜻')
rclpy.shutdown()
PY

echo; echo "== PointCloud2 한 장 — Rviz 에서 볼 자료 =="
ros2 topic echo --once --no-arr "$BASE/points" 2>&1 \
  | grep -E 'frame_id|height|width|point_step|row_step|is_dense' | sed 's/^/  /'
echo "  발행 주기:"
timeout 12 ros2 topic hz "$BASE/points" 2>&1 | grep -m1 average | sed 's/^/    /'
