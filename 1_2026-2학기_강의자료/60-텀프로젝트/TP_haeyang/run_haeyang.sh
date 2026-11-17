#!/usr/bin/env bash
# run_haeyang.sh — 해양누리공원 월드(haeyangnuri)를 띄운다
#
#   bash run_haeyang.sh                  # lite 판, 창을 띄운다 (권장)
#   bash run_haeyang.sh lite headless    # 화면 없이 서버만 — RTF 를 잴 때
#   DRY=1 bash run_haeyang.sh            # 명령만 확인
#
#   TP_vrx_lite/run_vrx_term.sh 와 다른 곳 두 군데
#     1) 월드가 이 폴더의 haeyangnuri.sdf (3·15 해양누리공원 앞 수역)
#     2) competition.launch.py 대신 이 폴더의 haeyang.launch.py 를 쓴다
#        — 배를 출발선 (0, -32, 북쪽) 에 띄우기 위해. 까닭은 haeyang.launch.py 머리말 참고
#
#   한글 경로를 피해 ASCII 경로로 복사한 뒤 띄우는 까닭,
#   <world name="..."> 이 파일 이름과 같아야 하는 까닭은 run_vrx_term.sh 머리말과 같다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITE="$HERE/../TP_vrx_lite"
GRADE="${1:-lite}"
MODE="${2:-gui}"

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

case "$GRADE" in
  lite|ultralite|full) ;;
  *) echo "판: lite · ultralite · full   /   모드: gui · headless · shot"; exit 1 ;;
esac

#  월드 — ASCII 경로로 복사한다
WDIR="$HOME/capstone_ws/worlds"
mkdir -p "$WDIR"
SRC_SDF="$HERE/haeyangnuri.sdf"
[ -f "$SRC_SDF" ] || { echo "월드 파일이 없음: $SRC_SDF"; exit 1; }
cp -f "$SRC_SDF" "$WDIR/haeyangnuri.sdf"
WORLD="$WDIR/haeyangnuri"              # 확장자를 뺀다 — launch 가 .sdf 를 붙인다
echo "월드      : $WDIR/haeyangnuri.sdf   ($(grep -c '<model name=' "$WDIR/haeyangnuri.sdf") 개 모델)"

#  배 — TP_vrx_lite 의 make_wamv_term.sh 를 그대로 쓴다 (같은 배, 같은 센서)
U="$HOME/capstone_ws/wamv/wamv_term_${GRADE}.urdf"
[ -f "$U" ] || { echo "$U 가 없어서 먼저 만든다"; bash "$LITE/make_wamv_term.sh" "$GRADE" || exit 1; echo; }

if grep -q 'type="camera"\|type="gpu_ray"\|type="gpu_lidar"' "$U"; then
  GZ="--render-engine-server ogre --render-engine-gui ogre"
else
  GZ="--render-engine-gui ogre"
fi

#  배를 띄울 자리 — 출발선. 바꾸려면 START_X / START_Y / START_YAW 로 준다
SX="${START_X:-0}"
SY="${START_Y:--32}"
SYAW="${START_YAW:-1.5708}"

case "$MODE" in
  gui)      ARGS=("urdf:=$U" "extra_gz_args:=$GZ") ;;
  headless) ARGS=("urdf:=$U" "headless:=true") ;;
  shot)     ARGS=("urdf:=$U" "extra_gz_args:=$GZ --gui-config $HERE/../../10-주차별-강의자료/W06_vrx_lite/gui_shot.config") ;;
  *) echo "모드: gui · headless · shot"; exit 1 ;;
esac
ARGS+=("x:=$SX" "y:=$SY" "yaw:=$SYAW")

if [ -z "$DRY" ] && [ -z "$IGNORE_GUI" ]; then
  [ "$MODE" = headless ] || bash "$HERE/../../10-주차별-강의자료/W03_vrx_lite/check_gui.sh" || exit 1
fi

if [ -z "$ROS_DOMAIN_ID" ]; then
  echo "경고: ROS_DOMAIN_ID 가 비어 있음 → 0 으로 뜸. 명령 안에 export ROS_DOMAIN_ID=7 을 적는다"
fi
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}   GZ_PARTITION=${GZ_PARTITION:-<안 정함: hostname:username>}"
echo "쓰는 URDF : $U   (센서 판 $GRADE)"
echo "배 자리   : x=$SX  y=$SY  yaw=$SYAW rad"
echo "위도/경도 : 월드 원점이 3·15 해양누리공원 앞 수역 (35.1862095 N, 128.5665903 E)"
echo "토픽"
echo "  /wamv/thrusters/{left,right,bow}/thrust                 std_msgs/msg/Float64 [N]"
echo "  /wamv/sensors/lidars/lidar_wamv_sensor/points           sensor_msgs/msg/PointCloud2"
echo "  /wamv/sensors/cameras/front_camera_sensor/image_raw     sensor_msgs/msg/Image"
echo "  /wamv/sensors/gps/gps/fix                               sensor_msgs/msg/NavSatFix"
echo "실행 명령:"
printf '  ros2 launch %s/haeyang.launch.py world:=%s' "$HERE" "$WORLD"
for a in "${ARGS[@]}"; do printf ' "%s"' "$a"; done; echo
[ -n "$DRY" ] && exit 0
echo
echo "띄운 뒤"
echo "  1) 배를 풀어 준다 : gz topic -t /vrx/release -m gz.msgs.Empty -p ''"
echo "  2) 끝낼 때        : 이 터미널에서 Ctrl+C,  그래도 남으면 bash $LITE/stop_vrx.sh"
exec ros2 launch "$HERE/haeyang.launch.py" world:="$WORLD" "${ARGS[@]}"
