#!/usr/bin/env bash
#  가제보 화면을 **고정 탑다운**으로 두고 일정 간격으로 떠낸다
#
#    bash gz_shot_log.sh <받을 초> <내보낼 폴더> [간격 초] [칸] [카메라 ENU x] [ENU y] [고도 m]
#
#  왜 바깥에서 찍는가
#    sim() 이 도는 동안 MATLAB 은 묶여 있어 한 발짝도 움직이지 못한다.
#    그래서 가제보 쪽 그림은 **WSL 에서 따로** 받아 폴더에 쌓아 둔다.
#
#  왜 화면 캡처(스크린샷 도구)가 아니라 서비스인가
#    창을 떠내면 앞에 놓인 다른 창이 같이 찍힌다 (MATLAB 창이 찍힌 적 있음).
#    /gui/screenshot 은 **렌더러가 직접** 그려 내므로 가려짐과 무관하다.
#
#  왜 follow 를 쓰지 않는가 (2026-11-13 변경)
#    /gui/follow 는 카메라를 선박에 매단다. 카메라가 선박을 따라 **평행이동**
#    하므로 영상에서 선박이 늘 화면 한가운데에 머문다 — 실제로 얼마나
#    움직였는지가 보이지 않는다. 고정 카메라는 배경이 멈춰 있어 **이동량과
#    회전량을 눈으로 잴 수 있다**
#      (follow 는 월드 기준이라 선박과 같이 **돌지는 않는다**. 2026-11-13
#       검증: 선박을 90 deg 돌리니 화면에서 선박만 돌고 부표 줄은 그대로였다.
#       따라서 영상에서 보이던 회전은 카메라 탓이 아니라 실제 회전이었음)
#    이미 걸려 있는 follow 가 남아 있을 수 있으므로 **빈 이름으로 먼저 푼다**
#
#  카메라 자세 — 북이 위, 동이 오른쪽인 지도 방향
#    쿼터니언 (x, y, z, w) = (-0.5, 0.5, 0.5, 0.5)
#    카메라 전방(+X)을 월드 -Z(아래)로, 카메라 상방(+Z)을 월드 +Y(북)로 보낸다
#    보이는 폭은 대략 2 * 고도 * tan(30 deg) = 1.155 * 고도 [m]
#
#  /gui/screenshot 은 **폴더**를 받는다 — 파일 경로를 주면 true 만 돌려주고
#    아무것도 쓰지 않는다. 파일 이름은 가제보가 ISO 시각으로 붙인다.
#
#  찍은 그림을 곧바로 f_000001.png 로 **고쳐 이름 붙인다** — 가제보가 붙이는
#    이름에는 쌍점이 들어간다 (2026-11-13T12:24:59.png). 윈도는 쌍점을
#    대체 데이터 스트림 구분자로 읽어 **그 파일을 열지 못한다** (실측: ls 에는
#    보이는데 MATLAB isfile 이 0). WSL 쪽에서 바꿔 두면 둘 다 읽는다
#
#  index.txt 한 줄의 꼴 — 벽시계 시각[epoch s] 과 그때 찍힌 파일
#    파일 이름의 시각을 믿지 않는다. 짝 맞추기는 이 벽시계 시각으로 한다
#    (MATLAB 쪽 녹화도 posixtime 으로 같은 눈금을 쓴다)
#
#  set -u 를 쓰지 않는다 — ROS 의 setup.bash 가 미정의 변수를 읽어 멈춘다
DUR=${1:-60}
DIR=${2:-/tmp/gzshot}
IVL=${3:-0.4}
PART=${4:-a3}
CX=${5:--532}
CY=${6:-200}
ALT=${7:-30}

#  가제보 내부 통신은 ROS_DOMAIN_ID 가 아니라 GZ_PARTITION 으로 갈린다.
#    띄울 때 준 값과 같아야 그 세계가 보인다
export GZ_PARTITION=$PART

mkdir -p "$DIR"
rm -f "$DIR"/*.png "$DIR/index.txt"
: > "$DIR/index.txt"

#  [1] 남아 있는 follow 를 푼다 — 빈 이름이 해제 명령이다
gz service -s /gui/follow \
  --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean \
  --timeout 2000 --req 'data: ""' > /dev/null 2>&1

#  [2] 고정 탑다운 카메라를 한 번만 놓는다. 이후 건드리지 않는다
gz service -s /gui/move_to/pose \
  --reqtype gz.msgs.GUICamera --reptype gz.msgs.Boolean \
  --timeout 3000 \
  --req "pose: {position: {x: $CX, y: $CY, z: $ALT}, \
                orientation: {x: -0.5, y: 0.5, z: 0.5, w: 0.5}}" > /dev/null 2>&1

sleep 1                                       # 카메라가 자리 잡을 시간

END=$(( $(date +%s) + DUR ))
N=0
while [ "$(date +%s)" -lt "$END" ]; do
  S=$(date +%s.%N)
  gz service -s /gui/screenshot \
    --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean \
    --timeout 1500 --req "data: '$DIR'" > /dev/null 2>&1
  sleep 0.08                                  # 파일이 디스크에 닿을 짧은 틈
  #  아직 이름을 안 바꾼 것 가운데 가장 새것 — 없으면 이번에는 못 찍은 것이다
  F=$(ls -t "$DIR"/*.png 2>/dev/null | grep -v '/f_' | head -1)
  if [ -n "$F" ]; then
    N=$((N+1))
    G=$(printf '%s/f_%06d.png' "$DIR" "$N")
    mv -f "$F" "$G"
    echo "$S $G" >> "$DIR/index.txt"
  fi
  sleep "$IVL"
done
