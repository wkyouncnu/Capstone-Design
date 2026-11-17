#!/usr/bin/env bash
# topshots.sh — 요구조건 문서에 들어가는 **공중 시점 그림 여덟 장**을 한 번에 찍는다
#
#   bash run_haeyang.sh lite shot     # 먼저 가제보를 캡처용 창으로 띄우고
#   bash topshots.sh                  # 이 파일
#
#   찍는 자리는 view.sh 의 자리표를 그대로 쓴다 — 좌표를 두 군데 적지 않기 위해서다.
#   남는 곳 : 기본 $HOME/capstone_ws/hy_shots  (OUT 으로 바꾼다)
#
#   주의 : 가제보를 띄운 터미널과 **같은 GZ_PARTITION** 이어야 한다.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERC="$HERE/../TP_vrx_lite"
cd "$HERE"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-7}"
export GZ_PARTITION="${GZ_PARTITION:-hy1}"
export DISPLAY="${DISPLAY:-:0}"
source /opt/ros/humble/setup.bash

OUT="${OUT:-$HOME/capstone_ws/hy_shots}"
WAIT="${WAIT:-4}"
mkdir -p "$OUT"

#  카메라를 배에 붙여 두었으면 떼어 낸다 — 붙은 채로는 move_to 가 되돌려진다
gz service -s /gui/follow --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean \
   --timeout 3000 --req 'data: ""' > /dev/null 2>&1

#  <파일 이름> <view.sh 자리>
SHOTS="
00_top_all      all
00_top_course   course
00_top_gates    gates
00_top_wp1      wp1
00_top_dock     dock
00_top_search   search
00_top_wp2      wp2
00_top_obs      obs
00_top_goal     goal
00_top_bay      bay
"

while read -r name spot; do
  [ -z "$name" ] && continue
  bash view.sh "$spot" > /dev/null 2>&1 || { echo "자리 없음 : $spot"; continue; }
  sleep "$WAIT"                      # 화면이 다 그려지기를 기다린다
  python3 "$PERC/xcap.py" --name Gazebo --out "$OUT/$name.png" > /dev/null 2>&1 \
    && echo "찍음  $name.png   ($spot)" || echo "실패  $name.png"
done <<< "$SHOTS"

echo
echo "남은 곳 : $OUT"
