#!/usr/bin/env bash
# make_wamv_bow.sh — 선수추진기를 더한 WAM-V URDF 를 만든다 (6주차 2-2)
#
#   bash make_wamv_bow.sh                  # GPS · IMU · 참값 오도메트리 + 추진기 3개 (기본, 느린 노트북용)
#   bash make_wamv_bow.sh camera           # 위 + 전방 카메라 1대
#   bash make_wamv_bow.sh camera lidar     # 위 + 카메라 + 3D LiDAR
#
#   결과 : ~/capstone_ws/wamv/wamv_bow_lite.urdf   (OUT=경로 로 바꿀 수 있음)
#   VRX 원본 파일은 고치지 않는다. 추진기 배치만 이 폴더의 xacro 로 바꿔 넣는다.
#
#   3주차 make_wamv_lite.sh 와 다른 점 한 줄
#     yaml_thruster_generation:=true thruster_xacro_file:=<이 폴더의 xacro>

set -e
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT="${LAYOUT:-$HERE/wamv_bow_thrusters.xacro}"
OUT="${OUT:-$HOME/capstone_ws/wamv/wamv_bow_lite.urdf}"
mkdir -p "$(dirname "$OUT")"

[ -f "$LAYOUT" ] || { echo "추진기 배치 파일이 없음: $LAYOUT"; exit 1; }

# 기본 : 제어 실습에 필요한 세 가지만 켠다 (카메라·LiDAR 는 느린 노트북에서 RTF 를 떨어뜨린다)
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
  camera_enabled:=$CAMERA lidar_enabled:=$LIDAR \
  yaml_thruster_generation:=true thruster_xacro_file:="$LAYOUT" > "$OUT"

echo "만든 파일 : $OUT   ($(wc -l < "$OUT") 줄)"
echo "켠 센서   : GPS=$GPS IMU=$IMU 참값오도메트리=$GT 카메라=$CAMERA LiDAR=$LIDAR"
echo "센서 목록 :"
grep -o 'sensor name="[^"]*" type="[^"]*"' "$OUT" | sed 's/^/  /'
grep -q OdometryPublisher "$OUT" && echo '  plugin OdometryPublisher (참값 오도메트리)'
echo "추진기 토픽 :"
grep -o '<topic>thrusters/[^<]*</topic>' "$OUT" | sed 's|.*<topic>|  /wamv/|; s|</topic>||'
echo "추진기 조인트 위치 :"
grep -A3 'chassis_engine_joint' "$OUT" | grep -o 'xyz="[^"]*" rpy="[^"]*"' | sed 's/^/  /'
