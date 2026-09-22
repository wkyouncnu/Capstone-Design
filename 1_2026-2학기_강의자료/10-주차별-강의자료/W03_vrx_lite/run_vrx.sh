#!/usr/bin/env bash
# run_vrx.sh — 성능이 낮은 노트북에서도 VRX 를 띄운다 (3주차 2-3)
#
#   bash run_vrx.sh            # = lite. 이 폴더의 wamv_lite.urdf + GUI ogre   (권장)
#   bash run_vrx.sh mine       # make_wamv_lite.sh 로 직접 만든 ~/capstone_ws/wamv/wamv_lite.urdf + GUI ogre
#   bash run_vrx.sh full       # 원래 센서(카메라 3대 + LiDAR) + 서버·GUI ogre   (4주차 토픽 조사용)
#   bash run_vrx.sh original   # 원래 명령 그대로 (비교용 — 느린 노트북에서는 화면이 멈춘 것처럼 보임)
#
#   명령만 확인   : DRY=1 bash run_vrx.sh mine
#   월드를 바꾸려면 : WORLD=2023_practice/practice_2023_wayfinding0_task bash run_vrx.sh
#   실제로 실행하는 ros2 launch 명령을 먼저 화면에 찍는다 — 직접 칠 때와 똑같다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-lite}"
WORLD="${WORLD:-sydney_regatta}"

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

case "$MODE" in
  lite)     U="$HERE/wamv_lite.urdf" ;;
  mine)     U="$HOME/capstone_ws/wamv/wamv_lite.urdf"
            [ -f "$U" ] || { echo "$U 가 없음. 먼저: bash $HERE/make_wamv_lite.sh"; exit 1; } ;;
esac
case "$MODE" in
  lite|mine)
            # 카메라 · LiDAR 는 서버가 그림을 그리는 센서 → 켰으면 서버 엔진도 ogre 로
            if grep -q 'type="camera"\|type="gpu_ray"\|type="gpu_lidar"' "$U"; then
              ARGS=("urdf:=$U" "extra_gz_args:=--render-engine-server ogre --render-engine-gui ogre")
            else
              ARGS=("urdf:=$U" "extra_gz_args:=--render-engine-gui ogre")
            fi ;;
  full)     ARGS=("extra_gz_args:=--render-engine-server ogre --render-engine-gui ogre") ;;
  original) ARGS=() ;;
  *) echo "모드: lite · mine · full · original"; exit 1 ;;
esac

# MATLAB · Simulink 와 같은 도메인이어야 토픽이 보인다 (2주차 2-5)
if [ -z "$ROS_DOMAIN_ID" ]; then
  echo "경고: ROS_DOMAIN_ID 가 비어 있음 → 0 으로 뜸. ~/.bashrc 의 export ROS_DOMAIN_ID=... 를 확인"
fi
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}  (MATLAB W0X_setup 의 값과 같아야 함)"
echo "실행 명령:"
printf '  ros2 launch vrx_gz competition.launch.py world:=%s' "$WORLD"
for a in "${ARGS[@]}"; do printf ' "%s"' "$a"; done; echo
[ -n "$DRY" ] && exit 0          # DRY=1 bash run_vrx.sh mine : 명령만 보고 실행하지 않음
echo "끝낼 때는 이 터미널에서 Ctrl+C"
exec ros2 launch vrx_gz competition.launch.py world:="$WORLD" "${ARGS[@]}"
