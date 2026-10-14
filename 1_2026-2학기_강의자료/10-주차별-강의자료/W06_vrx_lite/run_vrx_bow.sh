#!/usr/bin/env bash
# run_vrx_bow.sh — 선수추진기를 단 WAM-V 로 VRX 를 띄운다 (6주차 2-3)
#
#   bash run_vrx_bow.sh          # = lite. 이 폴더의 wamv_bow_lite.urdf + GUI ogre   (권장)
#   bash run_vrx_bow.sh mine     # make_wamv_bow.sh 로 직접 만든 ~/capstone_ws/wamv/wamv_bow_lite.urdf
#   bash run_vrx_bow.sh headless # 화면 없이 서버만 (측정 · 자동 실행용. 가장 가볍다)
#   bash run_vrx_bow.sh shot     # 3D 화면만 띄운다 (패널 없음) — 강의자료 그림 찍을 때
#
#   명령만 확인   : DRY=1 bash run_vrx_bow.sh
#   월드를 바꾸려면 : WORLD=sydney_regatta bash run_vrx_bow.sh
#
#   3주차 run_vrx.sh 와 쓰는 법이 같다. 다른 것은 URDF 하나 — 추진기가 둘에서 셋으로 늘었다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-lite}"
WORLD="${WORLD:-sydney_regatta}"

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

case "$MODE" in
  lite|shot|headless) U="$HERE/wamv_bow_lite.urdf" ;;
  mine)          U="$HOME/capstone_ws/wamv/wamv_bow_lite.urdf"
                 [ -f "$U" ] || { echo "$U 가 없음. 먼저: bash $HERE/make_wamv_bow.sh"; exit 1; } ;;
  *) echo "모드: lite · mine · shot · headless"; exit 1 ;;
esac
[ -f "$U" ] || { echo "URDF 가 없음: $U"; exit 1; }

case "$MODE" in
  # 카메라 · LiDAR 를 끈 URDF 이므로 서버는 그림을 그리지 않는다 → GUI 엔진만 ogre 로 낮춘다
  lite|mine) ARGS=("urdf:=$U" "extra_gz_args:=--render-engine-gui ogre") ;;
  headless)  ARGS=("urdf:=$U" "headless:=true") ;;
  # 그림 찍기 — 패널을 뺀 GUI 설정(gui_shot.config)으로 3D 화면만 띄운다.
  # 그림이 선명해야 하므로 GUI 엔진은 기본값 ogre2 를 쓴다 (lite 보다 조금 무겁다)
  shot)      ARGS=("urdf:=$U" "extra_gz_args:=--gui-config $HERE/gui_shot.config") ;;
esac

# MATLAB · Simulink 와 같은 도메인이어야 토픽이 보인다 (2주차 2-5)
if [ -z "$ROS_DOMAIN_ID" ]; then
  echo "경고: ROS_DOMAIN_ID 가 비어 있음 → 0 으로 뜸. ~/.bashrc 의 export ROS_DOMAIN_ID=... 를 확인"
fi
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}  (MATLAB W06_setup 의 ros_domain_id 와 같아야 함)"
echo "쓰는 URDF  : $U"
echo "추진기 토픽: /wamv/thrusters/{left,right,bow}/thrust   (std_msgs/msg/Float64, 단위 N)"
echo "실행 명령:"
printf '  ros2 launch vrx_gz competition.launch.py world:=%s' "$WORLD"
for a in "${ARGS[@]}"; do printf ' "%s"' "$a"; done; echo
[ -n "$DRY" ] && exit 0          # DRY=1 bash run_vrx_bow.sh : 명령만 보고 실행하지 않음
echo "끝낼 때는 이 터미널에서 Ctrl+C"
exec ros2 launch vrx_gz competition.launch.py world:="$WORLD" "${ARGS[@]}"
