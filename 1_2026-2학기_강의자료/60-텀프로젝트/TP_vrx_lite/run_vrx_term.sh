#!/usr/bin/env bash
# run_vrx_term.sh — 텀프로젝트 월드(kaboat_term)를 띄운다
#
#   bash run_vrx_term.sh                 # = lite 판, 창을 띄운다   (권장)
#   bash run_vrx_term.sh ultralite       # 라이다·카메라를 더 낮춘 판 (RTF 가 0.3 아래일 때)
#   bash run_vrx_term.sh full            # VRX 원본 센서 — 비교용
#   bash run_vrx_term.sh lite headless   # 화면 없이 서버만 — RTF 를 잴 때
#
#   명령만 확인      : DRY=1 bash run_vrx_term.sh
#   다른 월드로 띄우려면 : WORLD=sydney_regatta bash run_vrx_term.sh
#
#   9주차 run_vrx_ca.sh 와 다른 곳 두 군데
#     1) 월드가 이 폴더의 kaboat_term.sdf 다 (9주차는 VRX 가 들고 있는 stationkeeping_task)
#     2) 그래서 월드 파일을 ASCII 경로로 한 번 복사한 뒤 띄운다 — 아래 설명
#
#   월드를 복사하는 까닭
#     이 저장소 경로에는 한글이 들어 있다 (1_2026-2학기_강의자료).
#     gz sim 은 월드 경로를 로케일에 맞춰 열므로 한글 경로에서 간헐적으로 못 찾는다.
#     ~/capstone_ws/worlds/ (전부 ASCII) 로 복사해 두고 그 경로로 띄운다.
#     월드를 고쳤으면 이 스크립트를 다시 돌리면 된다 — 매번 새로 복사한다.
#
#   월드 이름이 파일 이름과 같아야 하는 까닭
#     vrx_gz 의 competition.launch.py 는 월드 인자의 basename 으로
#     /world/<이름>/create 서비스를 불러 배를 띄운다. 파일이 kaboat_term.sdf 인데
#     <world name="..."> 가 다르면 **배가 생성되지 않는다** (오류도 안 난다).
#     kaboat_term.sdf 안의 이름은 kaboat_term 으로 맞춰 두었다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
if [ -z "$WORLD" ]; then
  SRC_SDF="$HERE/kaboat_term.sdf"
  [ -f "$SRC_SDF" ] || { echo "월드 파일이 없음: $SRC_SDF"; exit 1; }
  cp -f "$SRC_SDF" "$WDIR/kaboat_term.sdf"
  WORLD="$WDIR/kaboat_term"          # 확장자를 뺀다 — launch 가 .sdf 를 붙인다
  echo "월드      : $WDIR/kaboat_term.sdf   ($(grep -c '<model name=' "$WDIR/kaboat_term.sdf") 개 모델)"
else
  echo "월드      : $WORLD   (WORLD 로 지정됨)"
fi

U="$HOME/capstone_ws/wamv/wamv_term_${GRADE}.urdf"
#  없으면 그 자리에서 만든다 — 두 단계를 외우지 않아도 되게
[ -f "$U" ] || { echo "$U 가 없어서 먼저 만든다"; bash "$HERE/make_wamv_term.sh" "$GRADE" || exit 1; echo; }

#  URDF 안에 그림을 그리는 센서가 있는지 보고 렌더 엔진을 정한다 (3·9주차와 같은 판정)
#  텀프로젝트 배에는 카메라와 라이다가 둘 다 있으므로 늘 아래쪽으로 간다
if grep -q 'type="camera"\|type="gpu_ray"\|type="gpu_lidar"' "$U"; then
  GZ="--render-engine-server ogre --render-engine-gui ogre"
else
  GZ="--render-engine-gui ogre"
fi

case "$MODE" in
  gui)      ARGS=("urdf:=$U" "extra_gz_args:=$GZ") ;;
  headless) ARGS=("urdf:=$U" "headless:=true") ;;
  shot)     ARGS=("urdf:=$U" "extra_gz_args:=$GZ --gui-config $HERE/../../10-주차별-강의자료/W06_vrx_lite/gui_shot.config") ;;
  *) echo "모드: gui · headless · shot"; exit 1 ;;
esac

if [ -z "$DRY" ] && [ -z "$IGNORE_GUI" ]; then
  [ "$MODE" = headless ] || bash "$HERE/../../10-주차별-강의자료/W03_vrx_lite/check_gui.sh" || exit 1
fi

if [ -z "$ROS_DOMAIN_ID" ]; then
  echo "경고: ROS_DOMAIN_ID 가 비어 있음 → 0 으로 뜸. 명령 안에 export ROS_DOMAIN_ID=7 을 적는다"
fi
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}   GZ_PARTITION=${GZ_PARTITION:-<안 정함: hostname:username>}"
echo "쓰는 URDF : $U   (센서 판 $GRADE)"
echo "토픽"
echo "  /wamv/thrusters/{left,right,bow}/thrust                 std_msgs/msg/Float64 [N]"
echo "  /wamv/sensors/lidars/lidar_wamv_sensor/points           sensor_msgs/msg/PointCloud2"
echo "  /wamv/sensors/cameras/front_camera_sensor/image_raw     sensor_msgs/msg/Image"
echo "  /wamv/sensors/cameras/front_camera_sensor/camera_info   sensor_msgs/msg/CameraInfo"
echo "실행 명령:"
printf '  ros2 launch vrx_gz competition.launch.py world:=%s' "$WORLD"
for a in "${ARGS[@]}"; do printf ' "%s"' "$a"; done; echo
[ -n "$DRY" ] && exit 0
echo
echo "띄운 뒤"
echo "  1) 배를 풀어 준다          : gz topic -t /vrx/release -m gz.msgs.Empty -p ''"
echo "  2) 미션 지점으로 옮긴다    : bash goto.sh start   (지점 목록은 bash goto.sh 만 치면 나온다)"
echo "  3) 끝낼 때                 : 이 터미널에서 Ctrl+C,  그래도 남으면 bash stop_vrx.sh"
exec ros2 launch vrx_gz competition.launch.py world:="$WORLD" "${ARGS[@]}"
