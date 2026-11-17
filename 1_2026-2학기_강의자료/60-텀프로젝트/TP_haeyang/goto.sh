#!/usr/bin/env bash
# goto.sh — WAM-V 를 미션 지점으로 순간이동시킨다 (해양누리공원 월드용, 확인 전용)
#
#   bash goto.sh                 # 지점 목록만 보여 준다
#   bash goto.sh start           # 출발선
#   bash goto.sh dock            # 도킹 베이 셋이 한 화면에 드는 자리
#   bash goto.sh -- 0 10 90      # 좌표를 직접 준다 (동 북 선수각[deg])
#
#   TP_vrx_lite/goto.sh 와 다른 곳
#     월드가 haeyangnuri 다. 좌표의 원점이 코스 한가운데이므로 숫자가 두 자리다
#     (옛 월드는 시드니 레가타 좌표를 물려받아 동 -5xx · 북 2xx 였다).
#     좌표의 출처는 haeyangnuri.sdf 이고, 그 원본은 make_haeyang_world.py 다.
#
#   왜 순간이동인가
#     이 폴더의 예제는 **인지가 되는지**만 확인한다 — 유도·제어는 Simulink 쪽 몫이다.
#     채점은 순간이동 없이, 출발선에서 한 번에 간다 (경기규정-202611 6.2(2) 연속 진행).
#
#   선수각 (yaw) 규약 — Gazebo ENU 기준
#     x = 동, y = 북.  yaw 0 = 동쪽을 봄, yaw 90 = 북쪽을 봄, yaw 180 = 서쪽을 봄.
#
#   주의
#     1) 띄운 터미널과 **같은 GZ_PARTITION** 을 주어야 서비스가 닿는다
#     2) 배를 풀어 두지 않았으면 (gz topic -t /vrx/release) 옮겨도 떠 있기만 한다
#     3) set_pose 는 속도를 0 으로 만들지 않는다 — 옮긴 뒤 3 초쯤 가라앉힌다

WORLD="${WORLD:-haeyangnuri}"
MODEL="${MODEL:-wamv}"

#  지점표 — 이름 : 동 북 선수각 : 설명
read -r -d '' POINTS <<'EOF'
start          0  -32  90  출발선. 배가 뜨는 자리. 첫 게이트(북 -24)를 8 m 앞에서 본다
gate1          0  -34  90  항로추종 1 번 게이트(폭 8 m) 10 m 앞
gate3          0  -18  90  항로추종 3 번 게이트(폭 9 m) 10 m 앞
wp1            0   10  90  위치유지 WP1. 주황 부표 위, 반경 5 m 링 안
dock           0   12  90  도킹 3 베이가 한 화면에 든다 (표식까지 17 m, 가시폭 29 m > 표식 간격 17 m)
dock_C         0   19  90  가운데 베이(초록 동그라미) 정면 3.5 m — 좌우 표식이 칸막이에 가린다
dock_W        -8.6 16.5 90  서쪽 베이(파란 네모) 정면 6 m
dock_E         8.6 16.5 90  동쪽 베이(빨간 세모) 정면 6 m
search_red   -19    6  90  탐색 빨강 부표 정면 8 m — 규정 5.2(6) 우현선회 대상
search_grn   -25   -2  90  탐색 초록 부표 정면 8 m — 우현선회 대상
search_ylw   -21  -10  90  탐색 노랑 부표 정면 8 m — 좌현선회 대상
wp2          -28   -9 180  위치유지 WP2. 주황 부표 위, 장애물 구간을 바라본다
obs_gate     -20   -3 180  장애물 진입 게이트(동 -30, 빨강 북 -8 · 초록 북 2) 10 m 앞
obs_front    -34   -3 180  로프 안쪽. 첫 차단벽(동 -38)이 4 m 앞 — 점군이 나오는지 본다
obs_mid      -48  -25 180  장애물 구간 가운데. 셋째 차단벽 열이 6 m 앞
goal         -60  -27 180  종료 게이트(동 -70, 빨강 북 -32 · 초록 북 -22) 10 m 앞
EOF

show() {
  echo "지점 목록  (bash goto.sh <이름>)      월드 : $WORLD"
  echo
  printf '  %-12s %7s %6s %6s  %s\n' 이름 동 북 선수각 설명
  printf '  %-12s %7s %6s %6s  %s\n' ------------ ------- ------ ------ -----------------------------------
  while read -r n x y yaw rest; do
    [ -z "$n" ] && continue
    printf '  %-12s %7s %6s %6s  %s\n' "$n" "$x" "$y" "$yaw" "$rest"
  done <<< "$POINTS"
  echo
  echo "  좌표를 직접 주려면 :  bash goto.sh -- <동> <북> <선수각deg>"
}

[ $# -eq 0 ] && { show; exit 0; }

if [ "$1" = "--" ]; then
  [ $# -ge 4 ] || { echo "쓰기: bash goto.sh -- <동> <북> <선수각deg>"; exit 1; }
  X="$2"; Y="$3"; YAW="$4"; NAME="(직접 지정)"; DESC=""
else
  LINE=$(grep -E "^$1 " <<< "$POINTS")
  [ -n "$LINE" ] || { echo "그런 지점이 없음: $1"; echo; show; exit 1; }
  read -r NAME X Y YAW DESC <<< "$LINE"
fi

source /opt/ros/humble/setup.bash >/dev/null 2>&1

#  yaw[deg] -> 쿼터니언 z, w   (z 축 회전만 있으므로 두 성분으로 끝난다)
read -r QZ QW <<< "$(python3 -c "
import math
h = math.radians(float('$YAW'))/2.0
print('%.9f %.9f' % (math.sin(h), math.cos(h)))
")"

echo "옮길 곳 : $NAME   동 $X · 북 $Y · 선수각 ${YAW} deg"
[ -n "$DESC" ] && echo "          $DESC"
echo "월드    : $WORLD   모델: $MODEL   GZ_PARTITION=${GZ_PARTITION:-<안 정함>}"

gz service -s "/world/$WORLD/set_pose" \
  --reqtype gz.msgs.Pose --reptype gz.msgs.Boolean --timeout 3000 \
  --req "name: \"$MODEL\", position: {x: $X, y: $Y, z: 0.0}, orientation: {z: $QZ, w: $QW}" \
  || { echo "실패. 가제보가 떠 있는지, GZ_PARTITION 이 띄운 터미널과 같은지 확인한다"; exit 1; }

#  파도에 흔들리던 자세가 가라앉기를 기다린다 — 바로 캡처하면 기울어진 화면이 나온다
sleep 3
echo "완료."
