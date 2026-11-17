#!/usr/bin/env bash
# run_ca_nodes.sh — 충돌회피 쪽(ROS 2) 노드를 한꺼번에 띄운다 (9주차 3-3)
#
#   순서는 둘이다. 먼저 시뮬레이터, 그 다음 이 스크립트다.
#     터미널 1 :  bash run_vrx_ca.sh
#     터미널 2 :  bash run_ca_nodes.sh
#
#   띄우는 것 셋 — 학생 PC 에서는 bin/ 의 **실행 파일**로 뜬다 (소스는 저장소에 없다)
#     bin/ca_bridge     참값 오도메트리 -> /wamv/gps_pose   (자를 하나로 맞춘다, 3-2)
#     bin/vfh_avoider   회피기. 노드 이름은 collision_avoidance_enu —
#                       라이다(.../lidar_wamv_sensor/scan)를 보고 /vfh/command 와 /vfh/oa_flag 를 낸다
#     bin/ca_viz        궤적 · 장애물 · 헤딩 명령 넷을 실시간으로 그린다 (2-6)
#   소스(ca_bridge.py · ca_viz.py · collision_avoidance_enu.py)가 이 폴더에 있으면 그것을 띄운다
#
#   띄우지 **않는** 것 둘 — 이 주차의 요점이 여기에 있다
#     heading_controller_enu   헤딩 제어는 시뮬링크가 한다 (5주차 PD 를 그대로 쓴다)
#     goal_publisher_enu       목표점은 시뮬링크의 웨이포인트 관리자가 낸다
#   연구실 원본 런치(vrx_avoidance_enu.launch.py) 는 이 둘까지 띄워서 제어까지 파이썬이
#   했다. 우리는 그 둘을 빼고 그 자리에 시뮬링크를 끼운다.
#
#   시뮬링크 없이 먼저 확인하고 싶을 때 (이음새를 붙이기 전의 점검)
#     GOAL="-532 312" DEMO_THRUST=1 bash run_ca_nodes.sh
#       GOAL        시뮬링크 대신 목표점을 한 번 박아 둔다 (ENU 로 "동 북")
#                   숫자는 월드마다 다르다. 지금 배가 어디 있는지는 이렇게 본다 :
#                     ros2 topic echo --once --field pose.pose.position \
#                       /wamv/sensors/position/ground_truth_odometry
#                   stationkeeping_task 에서는 배가 동 -532, 북 200 에서 뜬다 (실측).
#                   북 233 에 벽이 있고 그 사이(동 -559..-531)가 열린 문이다.
#                   위 값은 그 문을 지나 북쪽으로 112 m 앞을 찍은 것이다.
#                   목표를 500 m 밖에 두면 회피는 돌지만 배가 영영 닿지 않아
#                   그림에서 아무 일도 안 일어나는 것처럼 보인다
#       DEMO_THRUST 시뮬링크 대신 좌우 추진기를 같은 힘으로 민다 — 직진만 한다
#     이렇게 두면 배는 직진하는데 회피 명령만 바뀌는 것이 보인다. 즉 **명령이 나오는지**는
#     확인되고 **그 명령대로 도는지**는 확인되지 않는다. 도는 것은 시뮬링크를 붙여야 본다.
#
#     화면 없이 그림 한 장만 : VIZ_SAVE=/tmp/w09.png VIZ_SECS=25 bash run_ca_nodes.sh
#
#   끝낼 때는 Ctrl+C. 시뮬레이터까지 함께 내리려면 bash ../W03_vrx_lite/stop_vrx.sh

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash
: "${ROS_DOMAIN_ID:=7}"; export ROS_DOMAIN_ID
: "${VIZ_EVERY:=}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDS=()
#  끝날 때 — 먼저 곱게(TERM), 그래도 남으면 강제로(KILL) 끈다.
#  그림 창(ca_viz)은 TERM 을 받아도 창이 남아 CPU 한 코어를 100 % 쥔다 (2026-11-17 실측).
#  셋이 남으면 시뮬레이터가 느려져 MATLAB 쪽 동기 점검 k 가 1.39 까지 벌어졌다
cleanup() {
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
  sleep 0.5
  for p in "${PIDS[@]}"; do kill -9 "$p" 2>/dev/null; done
}
trap cleanup EXIT

#  앞서 띄운 것이 남아 있으면 먼저 끈다 — Ctrl+C 없이 터미널만 닫으면 남는다
pkill -9 -f "W09_vrx_lite/(bin/)?(ca_viz|ca_bridge|vfh_avoider|collision_avoidance_enu)" 2>/dev/null   && echo "앞서 띄운 회피 노드가 남아 있어 먼저 껐다"
pkill -9 -f "lib/vrx_control/collision_avoidance_enu" 2>/dev/null

echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
#  시뮬레이터가 떠 있는지 먼저 본다 — 안 떠 있으면 아래 노드들은 조용히 기다리기만 한다
if ! ros2 topic list 2>/dev/null | grep -q lidar_wamv_sensor; then
  echo "라이다 토픽이 안 보인다. 다른 터미널에서 먼저:  bash run_vrx_ca.sh"
  exit 1
fi

#  두 노드의 글은 로그로 보낸다 — 그림 띄운 터미널을 덮어쓰지 않게.
#  무슨 일이 있었는지는 tail -f /tmp/w09_ca_nodes.log 로 본다
LOG=/tmp/w09_ca_nodes.log
: > "$LOG"
echo "노드 로그: $LOG"

#  ── 셋을 무엇으로 띄울지 고른다 ─────────────────────────────────────────────
#  학생 PC  : 소스가 없다 → bin/ 의 실행 파일 (git pull 로 받은 것)
#  교수 PC  : 소스가 있다 → 소스를 그대로 (고치면 바로 반영된다)
#  USE_BIN=1 을 주면 소스가 있어도 실행 파일로 띄운다 — 배포본을 시험할 때
chmod +x "$HERE"/bin/* 2>/dev/null || true
pick() {   # $1 = 이름 (ca_bridge · ca_viz)  → CMD 배열
  if [ -z "$USE_BIN" ] && [ -f "$HERE/$1.py" ]; then CMD=(python3 "$HERE/$1.py")
  elif [ -f "$HERE/bin/$1" ];                     then CMD=("$HERE/bin/$1")
  else echo "$1 이 없다 — git pull 로 bin/$1 을 받을 것"; exit 1; fi
}
if   [ -z "$USE_BIN" ] && [ -f "$HERE/collision_avoidance_enu.py" ]; then
  AVO=(python3 "$HERE/collision_avoidance_enu.py");            AVO_SAY="소스 (이 폴더)"
elif [ -z "$USE_BIN" ] && ros2 pkg prefix vrx_control >/dev/null 2>&1; then
  AVO=(ros2 run vrx_control collision_avoidance_enu);          AVO_SAY="소스 (vrx_control 패키지)"
elif [ -f "$HERE/bin/vfh_avoider" ]; then
  AVO=("$HERE/bin/vfh_avoider");                               AVO_SAY="실행 파일 bin/vfh_avoider"
else
  echo "회피기가 없다 — git pull 로 bin/vfh_avoider 를 받을 것"; exit 1
fi
echo "회피기   : $AVO_SAY"

pick ca_bridge
"${CMD[@]}" >> "$LOG" 2>&1 & PIDS+=($!)
sleep 1

"${AVO[@]}" >> "$LOG" 2>&1 & PIDS+=($!)
sleep 1

#  ── 시뮬링크 자리를 임시로 메우는 둘 (점검용) ─────────────────────────────────
if [ -n "$GOAL" ]; then
  set -- $GOAL
  echo "목표점을 박아 둔다 (ENU): 동 $1, 북 $2   — 시뮬링크가 붙으면 이 줄은 빼도 된다"
  ros2 topic pub -r 1 /usv/state/goal_enu geometry_msgs/msg/Point \
       "{x: $1, y: $2, z: 0.0}" > /dev/null 2>&1 & PIDS+=($!)
fi

if [ -n "$DEMO_THRUST" ]; then
  F="${DEMO_THRUST_N:-600}"
  echo "좌우 추진기를 ${F} N 으로 민다 — 직진만 한다 (시뮬링크가 붙으면 이 줄은 뺀다)"
  gz topic -t /vrx/release -m gz.msgs.Empty -p '' 2>/dev/null || true
  for s in left right; do
    ros2 topic pub -r 10 "/wamv/thrusters/$s/thrust" std_msgs/msg/Float64 \
         "{data: $F}" > /dev/null 2>&1 & PIDS+=($!)
  done
fi

# ── 그림 ──────────────────────────────────────────────────────────────────────
if [ -n "$VIZ_SAVE" ]; then
  ARGS=(--save "$VIZ_SAVE" --secs "${VIZ_SECS:-20}")
  #  VIZ_EVERY 를 주면 그 초마다 번호를 붙여 여러 장 남긴다 — 회피는 한순간이라
  #  한 장만 찍으면 그 순간을 놓친다. 강의자료 그림 고를 때 쓴다
  [ -n "$VIZ_EVERY" ] && ARGS+=(--every "$VIZ_EVERY")
  pick ca_viz
  "${CMD[@]}" "${ARGS[@]}" & VIZ=$!
else
  pick ca_viz
  "${CMD[@]}" & VIZ=$!
fi
#  그림도 PIDS 에 넣어 둔다 — Ctrl+C 나 창 닫기 어느 쪽으로 끝나도 cleanup 이 마저 끈다
PIDS+=($VIZ)
wait $VIZ
