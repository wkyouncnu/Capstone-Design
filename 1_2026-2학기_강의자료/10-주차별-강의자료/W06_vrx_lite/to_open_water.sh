#!/usr/bin/env bash
# to_open_water.sh — WAM-V 를 넓은 물로 옮겨 놓는다 (6주차 G-4 · G-5 가 먼저 부른다)
#
#   bash to_open_water.sh                # ENU (-532, 200) — 5주차 경로 원점
#   bash to_open_water.sh -532 200 1.0   # x y yaw[rad] 를 직접
#
#   왜 옮기는가 (2026-10-16 노트북 실측)
#     VRX 원본의 스폰 ENU (-532, 162) 는 남쪽 해안에서 몇 m 밖에 안 떨어져 있다.
#     measure_sway.sh 250 10 이 배를 우현(남동쪽)으로 9.6 m 밀어 해안에 얹혔고,
#     그 접촉 때문에 요가 +33 deg 돌아 "요 유지 틀림" 이 나왔다 (반대쪽 -250 은 -4.9 deg).
#     열린 고리 측정은 제어기가 없으므로 시작 자리가 넓은 물이어야 한다.
#
#   방법: Gazebo 의 set_pose 서비스로 모델 'wamv' 의 자세를 바꾼다.
#         월드 이름 기본값 sydney_regatta — 다르면 WORLD=... bash to_open_water.sh

X="${1:--532}"
Y="${2:-200}"
YAW="${3:-1.0}"            # VRX 스폰과 같은 선수각 (ENU 1 rad = 57.3 deg)
WORLD="${WORLD:-sydney_regatta}"

QZ=$(python3 -c "import math; print(math.sin($YAW/2))")
QW=$(python3 -c "import math; print(math.cos($YAW/2))")

R=$(gz service -s /world/$WORLD/set_pose --reqtype gz.msgs.Pose --reptype gz.msgs.Boolean \
      --timeout 3000 --req "name: \"wamv\", position: {x: $X, y: $Y, z: 0.0}, orientation: {z: $QZ, w: $QW}")
case "$R" in
  *true*) echo "배를 넓은 물로 옮김 : ENU x=$X  y=$Y  yaw=$YAW rad  (3 초 기다려 가라앉힘)"; sleep 3 ;;
  *)      echo "set_pose 실패 — VRX 가 떠 있는지, 월드 이름($WORLD)이 맞는지 확인"; exit 1 ;;
esac
