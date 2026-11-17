# w09_world.sh — 9주차 장애물 월드를 쓸 채비를 한다. 직접 치지 않는다 (다른 스크립트가 source 한다)
#
#   VRX 원본의 stationkeeping_task 에는 **피할 장애물이 없다.** 그리고 배가 뜨는 자리가
#   (동 -532, 북 162) 로 코드에 박혀 있다 (competition.launch.py:46).
#   이 주차의 경로와 장애물 표는 (동 -532, 북 200) 에서 뜨는 배 + 기둥 41 개를 놓은 월드가 기준이다.
#   그래서 이 폴더가 월드와 장애물 모델, 띄울 자리를 받는 launch 를 들고 다닌다.
#   vrx 설치본(~/vrx_ws)은 건드리지 않는다.
#
#   하는 일 셋
#     1) world/stationkeeping_task.sdf 와 world/custom_obstacle/ 을 ASCII 경로로 복사
#        (~/capstone_ws/worlds/w09/ — 한글 경로를 gz 가 못 읽는 경우를 피한다)
#     2) GZ_SIM_RESOURCE_PATH 에 그 자리를 넣는다 — model://custom_obstacle 을 찾게
#     3) W09_WORLD (월드 경로) · W09_LAUNCH (launch 파일) · W09_SPAWN (자리 인자) 를 정한다
#
#   WORLD=sydney_regatta 처럼 **이름을** 주면 VRX 가 들고 있는 그 월드를 그대로 띄운다.

_W09_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W09_LAUNCH="$_W09_HERE/w09_ca.launch.py"
W09_SPAWN=("x:=${START_X:--532}" "y:=${START_Y:-200}" "yaw:=${START_YAW:-1.0}")

if [ -z "$WORLD" ]; then
  _W09_DIR="$HOME/capstone_ws/worlds/w09"
  mkdir -p "$_W09_DIR"
  cp -f  "$_W09_HERE/world/stationkeeping_task.sdf" "$_W09_DIR/" || return 1
  cp -rf "$_W09_HERE/world/custom_obstacle"         "$_W09_DIR/" || return 1
  export GZ_SIM_RESOURCE_PATH="$_W09_DIR${GZ_SIM_RESOURCE_PATH:+:$GZ_SIM_RESOURCE_PATH}"
  W09_WORLD="$_W09_DIR/stationkeeping_task"      # 확장자를 뺀다 — launch 가 .sdf 를 붙인다
else
  W09_WORLD="$WORLD"
fi
