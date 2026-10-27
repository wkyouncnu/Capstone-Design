#!/usr/bin/env bash
# make_wamv_ca.sh — 선수추진기 + 3D LiDAR 를 단 WAM-V URDF 를 만든다 (9주차 2-2)
#
#   bash make_wamv_ca.sh            # = lite.  16빔 x 440 =  7,040 점/스캔, 40m  (권장)
#   bash make_wamv_ca.sh ultralite  #    8빔 x 220 =  1,760 점/스캔, 30m  (RTF 가 0.3 아래일 때)
#   bash make_wamv_ca.sh full       #   16빔 x 1875 = 30,000 점/스캔, 130m (VRX 원본 그대로)
#
#   결과 : ~/capstone_ws/wamv/wamv_ca_<판>.urdf
#
#   6주차 make_wamv_bow.sh 와 다른 점 두 줄
#     yaml_component_generation:=true component_xacro_file:=<이 폴더의 components xacro>
#   추진기 배치는 6주차 것을 그대로 가져다 쓴다 — 선수추진기 단 배를 다시 만들지 않는다.
#
#   라이다 자리는 x=0.70, y=0, z=1.90 이다 (세 판 모두 같다).
#   z 는 계산이 아니라 실측으로 정했다 — probe_lidar_pose.sh 로 1.6~2.6 을 훑어 보니
#   1.75 이하에서는 들어온 값의 82% 가 장애물이 아니라 자기 배(cpu_cases_link,
#   윗면 z=1.765m) 였고 1.80 부터 0% 였다. 파도에 기우는 것까지 보아 1.90 으로 둔다.
#   까닭은 wamv_ca_components.xacro 주석에 적어 두었다.

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADE="${1:-lite}"

#  추진기 배치 — 6주차 것을 그대로. 여기서 다시 적지 않는다
LAYOUT="${LAYOUT:-$HERE/../W06_vrx_lite/wamv_bow_thrusters.xacro}"
COMPONENTS="${COMPONENTS:-$HERE/wamv_ca_components.xacro}"

#  라이다 성능 — 한 스캔의 점 수(빔 x 샘플) 가 RTF 를 정한다
case "$GRADE" in
  full)      export CA_LIDAR_BEAMS=16 CA_LIDAR_SAMPLES=1875 CA_LIDAR_RATE=10 CA_LIDAR_RANGE=130 ;;
  lite)      export CA_LIDAR_BEAMS=16 CA_LIDAR_SAMPLES=440  CA_LIDAR_RATE=10 CA_LIDAR_RANGE=40  ;;
  ultralite) export CA_LIDAR_BEAMS=8  CA_LIDAR_SAMPLES=220  CA_LIDAR_RATE=5  CA_LIDAR_RANGE=30  ;;
  *) echo "판: full · lite · ultralite 중에서 고름"; exit 1 ;;
esac

OUT="${OUT:-$HOME/capstone_ws/wamv/wamv_ca_${GRADE}.urdf}"
mkdir -p "$(dirname "$OUT")"

[ -f "$LAYOUT" ]     || { echo "추진기 배치 파일이 없음: $LAYOUT"; exit 1; }
[ -f "$COMPONENTS" ] || { echo "센서 배치 파일이 없음: $COMPONENTS"; exit 1; }

SRC="$(ros2 pkg prefix wamv_gazebo)/share/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro"
xacro "$SRC" \
  yaml_thruster_generation:=true  thruster_xacro_file:="$LAYOUT" \
  yaml_component_generation:=true component_xacro_file:="$COMPONENTS" > "$OUT"

PTS=$(( CA_LIDAR_BEAMS * CA_LIDAR_SAMPLES ))
echo "만든 파일 : $OUT   ($(wc -l < "$OUT") 줄)"
echo "라이다 판 : $GRADE"
printf '  세로 광선 %s개 x 한 바퀴 샘플 %s개 = %s 점/스캔,  %s Hz,  사거리 %s m\n' \
       "$CA_LIDAR_BEAMS" "$CA_LIDAR_SAMPLES" "$PTS" "$CA_LIDAR_RATE" "$CA_LIDAR_RANGE"
printf '  초당 점 수 = %s\n' "$(( PTS * CA_LIDAR_RATE ))"
echo "센서 목록 :"
grep -o 'sensor name="[^"]*" type="[^"]*"' "$OUT" | sed 's/^/  /'
grep -q OdometryPublisher "$OUT" && echo '  plugin OdometryPublisher (참값 오도메트리)'
#  라이다는 base_link 에 바로 붙지 않는다 — 마스트(post) · 팔(arm) · 센서, 관절 셋을
#  거친다. 그래서 자리를 보려면 세 관절의 원점을 더해야 한다 (0.63 + 0.03 + 0.04 = 0.70)
echo "라이다 자리 (base_link 기준, 관절 셋을 더한 값) :"
grep -A1 -e 'joint name="wamv/base_to_lidar_wamv_post_joint"' \
         -e 'joint name="wamv/lidar_wamv_post_to_lidar_wamv_post_arm_joint"' \
         -e 'joint name="wamv/lidar_wamv_post_arm_to_lidar_wamv_joint"' "$OUT" \
  | grep -o 'xyz="[^"]*"' | sed 's/xyz="//; s/"//' \
  | awk '{x+=$1; y+=$2; z+=$3} END {printf "  앞 x = %.2f m,  옆 y = %.2f m,  높이 z = %.2f m\n", x, y, z}'
echo "추진기 토픽 :"
grep -o '<topic>thrusters/[^<]*</topic>' "$OUT" | sed 's|.*<topic>|  /wamv/|; s|</topic>||'
echo "라이다 토픽 : /wamv/sensors/lidars/lidar_wamv_sensor/points  (sensor_msgs/msg/PointCloud2)"
