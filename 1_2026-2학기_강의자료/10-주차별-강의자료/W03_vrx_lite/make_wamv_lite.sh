#!/usr/bin/env bash
# make_wamv_lite.sh — 센서를 골라 켠 WAM-V URDF 를 만든다 (3주차 2-3)
#
#   bash make_wamv_lite.sh                  # GPS · IMU · 참값 오도메트리만 (기본)
#   bash make_wamv_lite.sh camera           # 위 + 전방 카메라 1대
#   bash make_wamv_lite.sh camera lidar     # 위 + 카메라 + 3D LiDAR
#
#   결과 : ~/capstone_ws/wamv/wamv_lite.urdf   (OUT=경로 로 바꿀 수 있음)
#   VRX 원본 파일은 고치지 않는다. xacro 에 인자만 넘긴다.

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

OUT="${OUT:-$HOME/capstone_ws/wamv/wamv_lite.urdf}"
mkdir -p "$(dirname "$OUT")"

# 기본 : 제어 실습에 필요한 세 가지만 켠다
GPS=true; IMU=true; GT=true; CAMERA=false; LIDAR=false
for s in "$@"; do
  case "$s" in
    camera) CAMERA=true ;;
    lidar)  LIDAR=true ;;
    *) echo "모르는 센서: $s   (camera · lidar 중에서 고름)"; exit 1 ;;
  esac
done

SRC="$(ros2 pkg prefix wamv_gazebo)/share/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro"
xacro "$SRC" \
  gps_enabled:=$GPS imu_enabled:=$IMU ground_truth_enabled:=$GT \
  camera_enabled:=$CAMERA lidar_enabled:=$LIDAR > "$OUT"

echo "만든 파일 : $OUT"
echo "켠 센서   : GPS=$GPS IMU=$IMU 참값오도메트리=$GT 카메라=$CAMERA LiDAR=$LIDAR"
echo "센서 목록 :"
grep -o 'sensor name="[^"]*" type="[^"]*"' "$OUT" | sed 's/^/  /'
grep -q OdometryPublisher "$OUT" && echo '  plugin OdometryPublisher (참값 오도메트리)'
