#!/usr/bin/env bash
# view.sh — 가제보 보기 카메라를 자리마다 옮긴다 (내려다보기 + 비스듬히 보기)
#
#   bash view.sh                         # 자리 목록
#   bash view.sh all                     # 코스 전체를 위에서
#   bash view.sh bird                    # 코스 전체를 남동쪽 공중에서 비스듬히
#   bash view.sh -- 0 -40 4  0 -5 1      # 카메라(동 북 높이) 와 보는 점(동 북 높이) 을 직접
#
#   TP_vrx_lite/topview.sh 와 다른 곳
#     그 쪽은 **늘 수직으로 내려다본다** (사원수를 박아 두었다).
#     이 쪽은 **보는 점**을 받아 자세를 계산하므로 눈높이에서 비스듬히도 본다.
#     수직 내려다보기는 보는 점을 카메라 바로 아래로 주면 그대로 나온다.
#
#   자세 계산
#     가제보 보기 카메라는 제 좌표계의 +X 가 앞, +Y 가 왼쪽, +Z 가 위다.
#     앞 벡터 f = normalize(보는 점 − 카메라) 로부터
#       피치 = asin(−f_z),  요 = atan2(f_y, f_x),  롤 = 0
#     수직 내려다보기(f = (0,0,−1), 요 90°) 를 넣으면
#     (w 0.5, x −0.5, y 0.5, z 0.5) — topview.sh 가 박아 둔 값과 같다. 검산 완료.
#
#   보이는 범위
#     shot 모드 창(1760x980)에서 **화소/m ≈ 897 / 높이** 다 — 보이는 폭 ≈ 2.0 x 높이, 높이 ≈ 1.1 x 높이 (수직 내려다볼 때).
#     즉 보이는 폭 ≈ 2.0 × 높이.
#
#   주의
#     1) 띄운 터미널과 **같은 GZ_PARTITION** 을 주어야 서비스가 닿는다
#     2) 가제보 창이 떠 있어야 한다 (headless 에는 GUI 서비스가 없다)
#     3) 옮긴 뒤 화면이 그려지기까지 2~3 초 걸린다 — 바로 캡처하면 옛 장면이 찍힌다

#  자리표 — 이름 : 카메라 동 북 높이 : 보는 점 동 북 높이 : 설명
read -r -d '' SPOTS <<'EOF'
all       -33   -4   70   -33   -4  0  코스 전체를 위에서. 일곱 구간이 한 화면에
course    -20   -3  110   -20   -3  0  코스 전체 + 둘레 바다와 공원 호안
land       25   -3  190    25   -3  0  육지까지. 공원 호안(서)·매립지 호안(동)
bird       45  -75   45   -30   -5  0  코스 전체를 남동쪽 공중에서 비스듬히
bird2    -130  -85   52   -35   -5  0  코스 전체를 남서쪽 공중에서 비스듬히
shore     120  -40   30   -40    0  2  매립지 쪽에서 공원 호안을 바라봄
start       0  -55   12     0  -20  0  출발선. 배가 뜨는 자리와 첫 게이트
gates       0  -12   28     0  -12  0  항로추종 게이트 열을 위에서
gates_eye   0  -40    4     0   -5  1  배 눈높이에서 게이트 열을 바라봄
wp1         0   10   13     0   10  0  위치유지 WP1
dock        0   26   17     0   26  0  도킹 — 베이 셋과 표지판을 위에서
dock_eye    0   11    3     0   27  2  배 눈높이에서 도킹 구조물을 바라봄 (선수 진입 시야)
dock_side -26   10   12     0   26  1  도킹 구조물을 남서쪽 공중에서 (스웨이 진입 쪽)
search    -22    6   16   -22    6  0  탐색 부표 셋 (빨강·초록·노랑)
wp2       -28   -9   12   -28   -9  0  위치유지 WP2 — 장애물 구간 바로 앞
obs       -50  -15   45   -50  -15  0  장애물 구간을 위에서
obs_eye   -24   -3    4   -55  -18  1  진입구에서 장애물 구간을 바라봄
goal      -70  -27   14   -70  -27  0  종료 게이트
EOF

show() {
  echo "자리 목록  (bash view.sh <이름>)"
  echo
  printf '  %-10s %17s %17s  %s\n' 이름 '카메라 동 북 높이' '보는 점 동 북 높이' 설명
  printf '  %-10s %17s %17s  %s\n' ---------- ----------------- ----------------- ---------------------------------
  while read -r n cx cy cz tx ty tz rest; do
    [ -z "$n" ] && continue
    printf '  %-10s %17s %17s  %s\n' "$n" "$cx $cy $cz" "$tx $ty $tz" "$rest"
  done <<< "$SPOTS"
  echo
  echo "  직접 줄 때 :  bash view.sh -- <카메라 동 북 높이> <보는 점 동 북 높이>"
}

[ $# -eq 0 ] && { show; exit 0; }

if [ "$1" = "--" ]; then
  CX="${2:?카메라 동}"; CY="${3:?카메라 북}"; CZ="${4:?카메라 높이}"
  TX="${5:?보는 점 동}"; TY="${6:?보는 점 북}"; TZ="${7:-0}"; NAME="(직접)"
else
  NAME="$1"
  LINE="$(grep -E "^$NAME " <<< "$SPOTS")"
  [ -z "$LINE" ] && { echo "그런 자리가 없다 : $NAME"; echo; show; exit 1; }
  read -r _ CX CY CZ TX TY TZ _ <<< "$LINE"
fi

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash 2>/dev/null

Q="$(python3 -c "
import math, sys
cx, cy, cz, tx, ty, tz = map(float, sys.argv[1:7])
dx, dy, dz = tx - cx, ty - cy, tz - cz
n = math.hypot(math.hypot(dx, dy), dz) or 1.0
fx, fy, fz = dx / n, dy / n, dz / n
pitch = math.asin(max(-1.0, min(1.0, -fz)))
yaw = math.atan2(fy, fx) if (fx or fy) else math.pi / 2   # 바로 아래를 볼 때는 북쪽을 위로
cp, sp = math.cos(pitch / 2), math.sin(pitch / 2)
cyw, syw = math.cos(yaw / 2), math.sin(yaw / 2)
print('%.6f %.6f %.6f %.6f %.1f %.1f' % (cyw * cp, -syw * sp, cyw * sp, syw * cp,
                                         math.degrees(pitch), math.degrees(yaw)))
" "$CX" "$CY" "$CZ" "$TX" "$TY" "$TZ")" || exit 1
read -r QW QX QY QZ PDEG YDEG <<< "$Q"

echo "보기 카메라 → 동 $CX · 북 $CY · 높이 $CZ m   ($NAME)"
echo "  보는 점 동 $TX · 북 $TY · 높이 $TZ m   → 피치 ${PDEG}° · 요 ${YDEG}°"
awk "BEGIN{if ($PDEG > 89.5) printf \"  수직 내려다보기 — 보이는 범위 약 %.0f x %.0f m\n\", 2.0*$CZ, 2.4*$CZ}"

gz service -s /gui/move_to/pose \
  --reqtype gz.msgs.GUICamera --reptype gz.msgs.Boolean --timeout 3000 \
  -r "pose: {position: {x: $CX, y: $CY, z: $CZ}, orientation: {w: $QW, x: $QX, y: $QY, z: $QZ}}" \
  | sed 's/^/  /'
