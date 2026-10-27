#!/usr/bin/env bash
# run_ca_nodes.sh — 충돌회피 쪽(ROS 2) 노드를 한꺼번에 띄운다 (9주차 3-3)
#
#   순서는 둘이다. 먼저 시뮬레이터, 그 다음 이 스크립트다.
#     터미널 1 :  bash run_vrx_ca.sh
#     터미널 2 :  bash run_ca_nodes.sh
#
#   띄우는 것 셋
#     ca_bridge.py           참값 오도메트리 -> /wamv/gps_pose   (자를 하나로 맞춘다, 3-2)
#     collision_avoidance_enu  /scan 을 보고 /vfh/command 와 /vfh/oa_flag 를 낸다
#     ca_viz.py              궤적 · 장애물 · 헤딩 명령 넷을 실시간으로 그린다 (2-6)
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
trap 'for p in "${PIDS[@]}"; do kill $p 2>/dev/null; done' EXIT

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

python3 "$HERE/ca_bridge.py" >> "$LOG" 2>&1 & PIDS+=($!)
sleep 1

ros2 run vrx_control collision_avoidance_enu >> "$LOG" 2>&1 & PIDS+=($!)
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
  python3 "$HERE/ca_viz.py" "${ARGS[@]}"
else
  python3 "$HERE/ca_viz.py"
fi
