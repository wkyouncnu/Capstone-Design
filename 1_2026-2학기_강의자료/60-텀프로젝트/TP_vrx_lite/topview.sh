#!/usr/bin/env bash
# topview.sh — 가제보 보기 카메라를 공중으로 올려 코스를 내려다본다
#
#   bash topview.sh                 # 자리 목록
#   bash topview.sh all             # 코스 전체
#   bash topview.sh dock            # 도킹 구역만
#   bash topview.sh -- -550 215 30  # 동 북 높이[m] 를 직접 준다
#
#   무엇을 하는가
#     가제보 GUI 의 `/gui/move_to/pose` 서비스에 카메라 자세를 넣는다.
#     배를 옮기는 goto.sh 와 다르다 — **보는 눈만** 옮긴다. 물리에 손대지 않는다.
#
#   자세 규약
#     바로 아래를 내려다보고 **북쪽이 화면 위**가 되는 자세는
#     롤 0 · 피치 +90° · 요 +90° 이고, 사원수로 (w 0.5, x −0.5, y 0.5, z 0.5) 다.
#     이 값은 바꿀 일이 없으므로 아래에 박아 두었다.
#
#   높이와 보이는 폭
#     1200x1000 창의 3 차원 화면은 783 x 953 화소다. 실측으로
#     높이 110 m 에서 3.57 화소/m 였으므로 **화소/m ≈ 393 / 높이** 다.
#     즉 보이는 폭 ≈ 2.0 × 높이, 창 전체로는 보이는 높이 ≈ 2.4 × 높이.
#     다만 문서에 넣을 때는 가로로 잘라 쓰므로 (xcap.py --crop 0,213,783,620)
#     **실제로 담기는 높이는 ≈ 1.6 × 높이** 다. 아래 자리표의 높이는 이 값을 기준으로 골랐다.
#
#   주의
#     1) 띄운 터미널과 **같은 GZ_PARTITION** 을 주어야 서비스가 닿는다
#     2) 가제보 창이 떠 있어야 한다 (headless 에서는 GUI 서비스가 없다)
#     3) 카메라를 옮긴 뒤 화면이 그려지기까지 2~3 초 걸린다 — 바로 캡처하면 옛 장면이 찍힌다

WORLD="${WORLD:-kaboat_term}"

#  자리표 — 이름 : 동 북 높이 : 설명
read -r -d '' SPOTS <<'EOF'
all     -556.5 200.5 50  코스 전체. 출발선부터 종료 게이트까지 일곱 구간이 한 화면에 든다
course  -556.5 200.5 72  코스 전체 + 둘레 바다. 경기장이 어디까지인지 보일 때
gates   -524.5 174.0 32  항로추종 게이트 열. 적·녹 한 쌍이 북쪽으로 줄지어 있는 것
wp1     -534.0 226.0 12  위치유지 WP1 — 주황 부표와 반경 5 m 링
dock    -550.5 229.5 14  도킹 ㄷ 자 구조물과 베이 셋
search  -549.3 194.0 15  탐색 부표 셋 (빨강·초록·노랑)
wp2     -553.0 188.0 12  위치유지 WP2 — 장애물 구간 바로 앞
obs     -576.7 196.5 26  장애물 구역. 가상경계선과 부표 격자
goal    -590.0 196.0 13  종료 게이트
EOF

show() {
  echo "자리 목록  (bash topview.sh <이름>)"
  echo
  printf '  %-8s %8s %7s %6s  %s\n' 이름 동 북 높이 설명
  printf '  %-8s %8s %7s %6s  %s\n' -------- -------- ------- ------ ------------------------------------
  while read -r n x y z rest; do
    [ -z "$n" ] && continue
    printf '  %-8s %8s %7s %6s  %s\n' "$n" "$x" "$y" "$z" "$rest"
  done <<< "$SPOTS"
  echo
  echo "  좌표를 직접 줄 때 :  bash topview.sh -- <동> <북> <높이>"
}

[ $# -eq 0 ] && { show; exit 0; }

if [ "$1" = "--" ]; then
  X="${2:?동 좌표}"; Y="${3:?북 좌표}"; Z="${4:?높이}"; NAME="(직접)"
else
  NAME="$1"
  LINE="$(grep -E "^$NAME " <<< "$SPOTS")"
  [ -z "$LINE" ] && { echo "그런 자리가 없다 : $NAME"; echo; show; exit 1; }
  read -r _ X Y Z _ <<< "$LINE"
fi

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash 2>/dev/null

echo "보기 카메라 → 동 $X · 북 $Y · 높이 $Z m   ($NAME)"
echo "  보이는 범위 약 $(awk "BEGIN{printf \"%.0f\", 2.0*$Z}") x $(awk "BEGIN{printf \"%.0f\", 2.4*$Z}") m   (가로로 잘라 쓰면 세로 $(awk "BEGIN{printf \"%.0f\", 1.6*$Z}") m)"

gz service -s /gui/move_to/pose \
  --reqtype gz.msgs.GUICamera --reptype gz.msgs.Boolean --timeout 3000 \
  -r "pose: {position: {x: $X, y: $Y, z: $Z}, orientation: {w: 0.5, x: -0.5, y: 0.5, z: 0.5}}" \
  | sed 's/^/  /'
