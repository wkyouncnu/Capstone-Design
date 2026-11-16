#!/usr/bin/env bash
# make_wamv_term.sh — 텀프로젝트 배의 URDF 를 만든다
#   선미 좌·우 추진기 + 선수추진기 (6주차) + 3D LiDAR (9주차) + 단안 카메라 (새로)
#
#   bash make_wamv_term.sh            # = lite.  라이다 7,040 점/스캔, 카메라 640x360 10 Hz (권장)
#   bash make_wamv_term.sh ultralite  #    라이다 1,760 점/스캔, 카메라 424x240  5 Hz
#   bash make_wamv_term.sh full       #    VRX 원본 그대로 (라이다 30,000 점, 카메라 1280x720 30 Hz)
#
#   결과 : ~/capstone_ws/wamv/wamv_term_<판>.urdf
#
#   9주차 make_wamv_ca.sh 와 다른 곳 두 군데
#     1) 센서 배치 파일이 wamv_term_components.xacro — 카메라 한 줄이 더 있다
#     2) 만든 URDF 의 카메라 해상도·주기를 sed 로 낮춘다
#        (wamv_camera 매크로가 해상도를 인자로 받지 않는다. 1280x720 30 Hz 고정이다)
#
#   카메라를 낮추는 까닭
#     WSL2 는 GPU 없이 소프트 렌더로 그린다. 1280x720 을 30 Hz 로 그리면
#     라이다 렌더까지 겹쳐 RTF 가 0.2 아래로 떨어진다. 인지 예제는 색 덩어리를
#     보는 일이라 640x360 으로 충분하다 — 10 m 앞 부표(지름 1.5 m)가 640 폭에서
#     약 60 픽셀로 잡힌다.
#
#   해상도를 낮추면 초점거리가 달라진다
#     fx = (W/2) / tan(HFOV/2),  HFOV = 1.3962634 rad (80 deg)
#       1280 -> fx = 762.7     640 -> fx = 381.4     424 -> fx = 252.7
#     그래서 인지 노드는 fx 를 손으로 적지 않고 camera_info 의 K 에서 읽는다.

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADE="${1:-lite}"

#  추진기 배치 — 6주차 것을 그대로 가져다 쓴다
LAYOUT="${LAYOUT:-$HERE/../../10-주차별-강의자료/W06_vrx_lite/wamv_bow_thrusters.xacro}"
COMPONENTS="${COMPONENTS:-$HERE/wamv_term_components.xacro}"

case "$GRADE" in
  full)      export CA_LIDAR_BEAMS=16 CA_LIDAR_SAMPLES=1875 CA_LIDAR_RATE=10 CA_LIDAR_RANGE=130
             CAM_W=1280 CAM_H=720 CAM_RATE=30 ;;
  lite)      export CA_LIDAR_BEAMS=16 CA_LIDAR_SAMPLES=440  CA_LIDAR_RATE=10 CA_LIDAR_RANGE=40
             CAM_W=640  CAM_H=360 CAM_RATE=10 ;;
  ultralite) export CA_LIDAR_BEAMS=8  CA_LIDAR_SAMPLES=220  CA_LIDAR_RATE=5  CA_LIDAR_RANGE=30
             CAM_W=424  CAM_H=240 CAM_RATE=5 ;;
  *) echo "판: full · lite · ultralite 중에서 고름"; exit 1 ;;
esac

OUT="${OUT:-$HOME/capstone_ws/wamv/wamv_term_${GRADE}.urdf}"
mkdir -p "$(dirname "$OUT")"

[ -f "$LAYOUT" ]     || { echo "추진기 배치 파일이 없음: $LAYOUT"; exit 1; }
[ -f "$COMPONENTS" ] || { echo "센서 배치 파일이 없음: $COMPONENTS"; exit 1; }

SRC="$(ros2 pkg prefix wamv_gazebo)/share/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro"
xacro "$SRC" \
  yaml_thruster_generation:=true  thruster_xacro_file:="$LAYOUT" \
  yaml_component_generation:=true component_xacro_file:="$COMPONENTS" > "$OUT"

#  카메라만 낮춘다. 라이다 블록에는 <width>/<height> 가 없으므로 섞이지 않는다
sed -i "s|<width>1280</width>|<width>${CAM_W}</width>|; s|<height>720</height>|<height>${CAM_H}</height>|" "$OUT"
#  update_rate 30.0 은 카메라 센서에만 있다 (라이다는 make 가 넣은 값)
sed -i "s|<update_rate>30.0</update_rate>|<update_rate>${CAM_RATE}.0</update_rate>|" "$OUT"

PTS=$(( CA_LIDAR_BEAMS * CA_LIDAR_SAMPLES ))
FX=$(python3 -c "import math; print(round((${CAM_W}/2)/math.tan(1.3962634/2), 1))")
echo "만든 파일 : $OUT   ($(wc -l < "$OUT") 줄)"
echo "판        : $GRADE"
printf '  라이다 : 세로 %s빔 x 샘플 %s = %s 점/스캔,  %s Hz,  사거리 %s m\n' \
       "$CA_LIDAR_BEAMS" "$CA_LIDAR_SAMPLES" "$PTS" "$CA_LIDAR_RATE" "$CA_LIDAR_RANGE"
printf '  카메라 : %sx%s,  %s Hz,  HFOV 80 deg  ->  fx = %s 픽셀\n' "$CAM_W" "$CAM_H" "$CAM_RATE" "$FX"
echo "센서 목록 :"
grep -o 'sensor type="[^"]*" name="[^"]*"\|sensor name="[^"]*" type="[^"]*"' "$OUT" | sed 's/^/  /'
echo "토픽 :"
echo "  /wamv/thrusters/{left,right,bow}/thrust                              std_msgs/msg/Float64 [N]"
echo "  /wamv/sensors/lidars/lidar_wamv_sensor/points                        sensor_msgs/msg/PointCloud2"
echo "  /wamv/sensors/cameras/front_camera_sensor/image_raw                  sensor_msgs/msg/Image"
echo "  /wamv/sensors/cameras/front_camera_sensor/camera_info                sensor_msgs/msg/CameraInfo"
