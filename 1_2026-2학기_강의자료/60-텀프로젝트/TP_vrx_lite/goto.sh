#!/usr/bin/env bash
# goto.sh — WAM-V 를 미션 지점으로 순간이동시킨다 (확인용)
#
#   bash goto.sh                 # 지점 목록만 보여 준다
#   bash goto.sh start           # 출발선
#   bash goto.sh dock            # 도킹 스테이션 세 개가 한 화면에 들어오는 자리
#   bash goto.sh -- -550 215 90  # 좌표를 직접 준다 (동 북 선수각[deg])
#
#   왜 순간이동인가
#     이 폴더의 예제는 **인지가 되는지**만 확인한다 — 유도·제어는 Simulink 쪽 몫이다.
#     배를 몰아 7 구간을 지나려면 매번 10 분이 든다. 확인할 지점으로 바로 옮기면
#     카메라 한 장·포인트클라우드 한 장을 몇 초에 받는다.
#     채점은 당연히 순간이동 없이, 출발선에서 한 번에 간다 (규정 6.2(2) 연속 진행).
#
#   선수각 (yaw) 규약 — Gazebo ENU 기준
#     x = 동, y = 북.  yaw 0 = 동쪽을 봄, yaw 90 = 북쪽을 봄, yaw 180 = 서쪽을 봄.
#     (수식·보고서에서 쓰는 NED 방위각과 부호가 다르다. 여기 숫자는 Gazebo 에 넣는 값이다)
#
#   주의
#     1) 띄운 터미널과 **같은 GZ_PARTITION** 을 주어야 서비스가 닿는다.
#        가제보를 둘 띄웠다면 특히 그렇다:  export GZ_PARTITION=a2; bash goto.sh dock
#     2) 배를 풀어 두지 않았으면 (gz topic -t /vrx/release) 옮겨도 떠 있기만 한다.
#     3) set_pose 는 속도를 0 으로 만들지 않는다. 달리던 중이면 옮긴 뒤 3 초쯤 가라앉힌다.

WORLD="${WORLD:-kaboat_term}"
MODEL="${MODEL:-wamv}"

#  지점표 — 이름 : 동 북 선수각 : 설명
#  좌표의 출처는 kaboat_term.sdf 이고, 그 원본은 make_term_world.py 다.
read -r -d '' POINTS <<'EOF'
start        -525 168  90  출발선. 항로추종 첫 게이트(북 174)를 12 m 앞에서 바라본다
gate1        -525 162  90  항로추종 1번 게이트 12 m 앞. 좌 초록·우 빨강 한 쌍이 화면 가운데 든다
gate4        -525 180  90  항로추종 중간. 게이트가 줄지어 보이는지 확인용
wp1          -534 226  90  위치유지 WP1. 주황 부표 위, 반경 5 m 표시 링 안
dock         -550 215  90  도킹 3 베이가 한 화면에 든다 (12 m 앞, 가시폭 20 m > 베이 폭 11 m)
dock_L       -556 222  90  왼쪽 베이(빨강 삼각) 정면 5 m
dock_C       -550 222  90  가운데 베이(초록 원) 정면 5 m
dock_R       -545 222  90  오른쪽 베이(파랑 네모) 정면 5 m
search_red   -542 198  90  탐색 빨강 부표 정면 8 m — 규정 5.2(6) 우현선회 대상
search_grn   -550 187  90  탐색 초록 부표 정면 8 m — 우현선회 대상
search_ylw   -556 197  90  탐색 노랑 부표 정면 8 m — 좌현선회 대상
wp2          -553 188 180  위치유지 WP2. 주황 부표 위, 반경 5 m 표시 링 안
obs_gate     -550 188 180  장애물 구역 진입 게이트(동 -560, 빨강 북192·초록 북184) 10 m 앞
obs_front    -560 188 180  가상경계선 위. 맨 앞 장애물 열(동 -564)이 4 m 앞 — 라이다 점이 나오는지 본다
obs_mid      -572 196 180  장애물 구역 가운데. 여러 열이 동시에 잡히는지 본다
goal         -584 196 180  종료 게이트(동 -594, 빨강 북200·초록 북192) 10 m 앞. 4 m 면 화면 밖이다
EOF

show() {
  echo "지점 목록  (bash goto.sh <이름>)"
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
import math,sys
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
echo "완료. 캡처는 shoot_cam.sh / RViz2 는 rviz_term.sh 참고"
