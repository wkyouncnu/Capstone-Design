#!/usr/bin/env bash
# run_vrx_ca.sh — 선수추진기 + 3D LiDAR 를 단 WAM-V 로 VRX 를 띄운다 (9주차 2-3)
#
#   bash run_vrx_ca.sh                 # = lite 판, 창을 띄운다   (권장)
#   bash run_vrx_ca.sh ultralite       # 라이다를 더 낮춘 판 (RTF 가 0.3 아래일 때)
#   bash run_vrx_ca.sh full            # VRX 원본 라이다 (30,000 점) — 비교용
#   bash run_vrx_ca.sh lite headless   # 화면 없이 서버만 — RTF 를 잴 때
#
#   명령만 확인   : DRY=1 bash run_vrx_ca.sh
#   월드를 바꾸려면 : WORLD=sydney_regatta bash run_vrx_ca.sh
#
#   6주차 run_vrx_bow.sh 와 다른 곳은 딱 한 군데다 — 렌더 엔진.
#   6주차 URDF 에는 그림을 그리는 센서가 없어서 서버는 아무것도 렌더하지 않았다.
#   라이다를 달면 서버가 매 스캔마다 장면을 그린다. 그래서 서버 엔진도 ogre 로 낮춘다.
#   (끄는 게 아니라 낮추는 것이다 — ogre2 는 WSL2 의 소프트 렌더에서 특히 비싸다)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADE="${1:-lite}"
MODE="${2:-gui}"
WORLD="${WORLD:-stationkeeping_task}"

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

case "$GRADE" in
  lite|ultralite|full) ;;
  *) echo "판: lite · ultralite · full   /   모드: gui · headless · shot"; exit 1 ;;
esac

U="$HOME/capstone_ws/wamv/wamv_ca_${GRADE}.urdf"
#  없으면 그 자리에서 만든다 — 두 단계를 외우지 않아도 되게
[ -f "$U" ] || { echo "$U 가 없어서 먼저 만든다"; bash "$HERE/make_wamv_ca.sh" "$GRADE" || exit 1; echo; }

#  URDF 안에 그림을 그리는 센서가 있는지 보고 렌더 엔진을 정한다 (3주차 run_vrx.sh 와 같은 판정)
if grep -q 'type="camera"\|type="gpu_ray"\|type="gpu_lidar"' "$U"; then
  GZ="--render-engine-server ogre --render-engine-gui ogre"
else
  GZ="--render-engine-gui ogre"
fi

case "$MODE" in
  gui)      ARGS=("urdf:=$U" "extra_gz_args:=$GZ") ;;
  headless) ARGS=("urdf:=$U" "headless:=true") ;;
  shot)     ARGS=("urdf:=$U" "extra_gz_args:=--gui-config $HERE/../W06_vrx_lite/gui_shot.config") ;;
  *) echo "모드: gui · headless · shot"; exit 1 ;;
esac

if [ -z "$DRY" ] && [ -z "$IGNORE_GUI" ]; then
  [ "$MODE" = headless ] || bash "$HERE/../W03_vrx_lite/check_gui.sh" || exit 1
fi

if [ -z "$ROS_DOMAIN_ID" ]; then
  echo "경고: ROS_DOMAIN_ID 가 비어 있음 → 0 으로 뜸. ~/.bashrc 의 export ROS_DOMAIN_ID=... 를 확인"
fi
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}  (MATLAB W09_setup 의 ros_domain_id 와 같아야 함)"
echo "쓰는 URDF  : $U   (라이다 판 $GRADE)"
echo "추진기 토픽: /wamv/thrusters/{left,right,bow}/thrust   (std_msgs/msg/Float64, 단위 N)"
echo "라이다 토픽: /wamv/sensors/lidars/lidar_wamv_sensor/points   (sensor_msgs/msg/PointCloud2)"
echo "실행 명령:"
printf '  ros2 launch vrx_gz competition.launch.py world:=%s' "$WORLD"
for a in "${ARGS[@]}"; do printf ' "%s"' "$a"; done; echo
[ -n "$DRY" ] && exit 0
echo "띄운 뒤 배를 풀어 주어야 움직인다:  gz topic -t /vrx/release -m gz.msgs.Empty -p ''"
echo "끝낼 때는 이 터미널에서 Ctrl+C"
exec ros2 launch vrx_gz competition.launch.py world:="$WORLD" "${ARGS[@]}"
