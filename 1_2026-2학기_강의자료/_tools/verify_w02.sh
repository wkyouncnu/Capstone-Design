#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# verify_w02.sh — W02 문서에 실린 명령을 문서 순서대로 실제로 실행해 검증한다.
#
#   WSL 안에서 실행한다
#     wsl -d Ubuntu-22.04 -u <사용자> -- bash /mnt/c/.../verify_w02.sh
#   또는 우분투로 복사해서
#     bash ~/verify_w02.sh
#
#   왜 필요한가
#     문서의 명령이 "예전에는 됐던" 상태로 남는 것이 강의자료가 썩는 방식이다.
#     학생이 첫 줄부터 따라 했을 때 되는지를 매번 기계가 확인한다.
#
#   합격선 — FAIL 0
# ---------------------------------------------------------------------------
# ROS 의 setup.bash 는 미설정 변수를 참조한다. set -u 를 켜면 source 에서 셸이 죽는다.
set +u
PASS=0; FAIL=0; SKIP=0
RESULTS=""

ok()   { PASS=$((PASS+1)); RESULTS="$RESULTS\n  [PASS] $1"; echo "  [PASS] $1"; }
ng()   { FAIL=$((FAIL+1)); RESULTS="$RESULTS\n  [FAIL] $1  -- $2"; echo "  [FAIL] $1  -- $2"; }
skip() { SKIP=$((SKIP+1)); RESULTS="$RESULTS\n  [SKIP] $1  -- $2"; echo "  [SKIP] $1  -- $2"; }

# 출력에 기대 문자열이 있으면 통과
expect() {          # expect <이름> <기대문자열> <명령...>
  local name=$1 want=$2; shift 2
  local out
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -q -- "$want"; then ok "$name"
  else ng "$name" "기대: '$want' / 실제 앞부분: $(printf '%s' "$out" | head -1)"; fi
}

echo "==================== W02 문서 검증 ===================="
echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# ---------- §2-1 설치 ----------
echo "[§2-1] ROS 2 설치"
source /opt/ros/humble/setup.bash 2>/dev/null
expect "ros2 명령 존재"            "ros2"     bash -c 'which ros2'
expect "ROS_DISTRO = humble"       "humble"   bash -ic 'printenv ROS_DISTRO'
expect "ROS_DOMAIN_ID 설정됨"      ""         bash -ic 'printenv ROS_DOMAIN_ID'
expect ".bashrc 자동 적용"          "opt/ros/humble/setup.bash" bash -c 'grep opt/ros/humble/setup.bash ~/.bashrc'
expect "ros2 doctor 통과"          "checks passed" bash -c 'timeout 60 ros2 doctor 2>&1 | tail -3'
expect "colcon 존재"               "colcon"   bash -c 'which colcon'
expect "rviz2 존재"                "rviz2"    bash -c 'which rviz2'
expect "rqt 존재"                  "rqt"      bash -c 'which rqt'
echo

# ---------- §2-2 VS Code · interop ----------
echo "[§2-2] VS Code 연동"
if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
  expect "WSL interop 켜짐"        "enabled"  bash -c 'cat /proc/sys/fs/binfmt_misc/WSLInterop'
  expect "code 명령 보임"           "code"     bash -c 'which code'
else
  ng "WSL interop 켜짐" "/proc/sys/fs/binfmt_misc/WSLInterop 없음 — 막혔을 때 절 참조"
fi
expect "Windows 디스크 접근"        "Users"    bash -c 'ls /mnt/c'
echo

# ---------- §2-3 첫 통신 ----------
echo "[§2-3] talker / listener"
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-7}
ros2 run demo_nodes_cpp talker  > /tmp/v_talker.log   2>&1 &
ros2 run demo_nodes_py  listener > /tmp/v_listener.log 2>&1 &
sleep 8
expect "talker 발행"   "Publishing" bash -c 'cat /tmp/v_talker.log'
expect "listener 수신" "I heard"    bash -c 'cat /tmp/v_listener.log'
expect "노드 2개 보임" "/talker"    bash -c 'timeout 10 ros2 node list'
expect "hz 측정"       "average rate" bash -c 'timeout 12 ros2 topic hz /chatter 2>&1 | tail -3'
expect "info --verbose" "Reliability" bash -c 'timeout 10 ros2 topic info /chatter --verbose'
pkill -f 'demo_nodes_cpp talker'   2>/dev/null
pkill -f 'demo_nodes_py listener'  2>/dev/null
sleep 2
echo

# ---------- §2-4 turtlesim ----------
echo "[§2-4] turtlesim — 토픽·서비스·액션·파라미터"
if [ -n "${DISPLAY:-}" ] && xdotool getdisplaygeometry >/dev/null 2>&1; then
  ros2 run turtlesim turtlesim_node > /tmp/v_turtle.log 2>&1 &
  sleep 9
  expect "turtlesim 노드"     "/turtlesim"            bash -c 'timeout 10 ros2 node list'
  expect "cmd_vel 토픽"       "/turtle1/cmd_vel"      bash -c 'timeout 10 ros2 topic list'
  expect "서비스 /spawn"      "/spawn"                bash -c 'timeout 10 ros2 service list'
  expect "액션 rotate"        "rotate_absolute"       bash -c 'timeout 10 ros2 action list'
  expect "파라미터 background" "background_b"          bash -c 'timeout 20 ros2 param list'
  expect "서비스 호출 spawn"  "turtle2"               bash -c "timeout 15 ros2 service call /spawn turtlesim/srv/Spawn \"{x: 2.0, y: 8.0, theta: 0.0, name: 'turtle2'}\""
  expect "파라미터 변경"      "successful"            bash -c 'timeout 10 ros2 param set /turtlesim background_g 140'
  expect "/clear 서비스"      "Empty_Response"        bash -c 'timeout 10 ros2 service call /clear std_srvs/srv/Empty {}'
  expect "액션 목표 달성"     "SUCCEEDED"             bash -c 'timeout 20 ros2 action send_goal /turtle1/rotate_absolute turtlesim/action/RotateAbsolute "{theta: 1.57}"'
  pkill -f turtlesim_node 2>/dev/null
  sleep 2
else
  skip "turtlesim 전체" "DISPLAY 가 없다 (GUI 없는 환경)"
fi
echo

# ---------- §2-7 저장소에서 받기 ----------
echo "[§2-7] usv_basics 저장소"
WS=/tmp/verify_ws
rm -rf "$WS"; mkdir -p "$WS/src"
if timeout 90 git clone -q https://github.com/wkyouncnu/usv_basics.git "$WS/src/usv_basics" 2>/tmp/v_clone.log; then
  ok "GitHub 에서 clone"
  expect "package.xml 존재" "package.xml" bash -c "ls $WS/src/usv_basics"
  ( cd "$WS" && timeout 180 colcon build --symlink-install > /tmp/v_build.log 2>&1 )
  expect "colcon build 성공" "1 package finished" bash -c 'cat /tmp/v_build.log'
  # shellcheck disable=SC1090
  source "$WS/install/setup.bash" 2>/dev/null
  expect "실행파일 4개 등록" "simple_talker" bash -c 'timeout 10 ros2 pkg executables usv_basics'

  # ---------- §2-8 내 노드 ----------
  echo
  echo "[§2-8] simple_talker / simple_listener"
  ros2 run usv_basics simple_talker   > /tmp/v_mytalker.log   2>&1 &
  ros2 run usv_basics simple_listener > /tmp/v_mylistener.log 2>&1 &
  sleep 8
  expect "내 발행자"  "published: USV alive" bash -c 'cat /tmp/v_mytalker.log'
  expect "내 구독자"  "received: USV alive"  bash -c 'cat /tmp/v_mylistener.log'
  expect "주기 2 Hz"  "average rate: 2"      bash -c 'timeout 12 ros2 topic hz /usv_chatter 2>&1 | tail -3'
  pkill -f 'usv_basics/simple_talker'   2>/dev/null
  pkill -f 'usv_basics/simple_listener' 2>/dev/null
  sleep 2

  # ---------- §2-9 QoS ----------
  echo
  echo "[§2-9] QoS 불일치"
  ros2 run usv_basics qos_test_pub > /tmp/v_qp.log 2>&1 &
  ros2 run usv_basics qos_test_sub > /tmp/v_qs.log 2>&1 &
  sleep 8
  expect "정상 상태에서 수신" "received: best effort" bash -c 'cat /tmp/v_qs.log'
  pkill -f qos_test_pub 2>/dev/null; pkill -f qos_test_sub 2>/dev/null
  sleep 2
  # 일부러 어긋나게 바꿔 경고가 나오는지 본다
  # 주석 문구에 기대지 않는다. reliability= 가 있는 줄만 바꾼다
  sed -i '/reliability=ReliabilityPolicy/s/BEST_EFFORT/RELIABLE/' \
      "$WS/src/usv_basics/usv_basics/qos_test_sub.py"
  ( cd "$WS" && timeout 180 colcon build --symlink-install > /tmp/v_build2.log 2>&1 )
  source "$WS/install/setup.bash" 2>/dev/null
  ros2 run usv_basics qos_test_pub > /tmp/v_qp2.log 2>&1 &
  ros2 run usv_basics qos_test_sub > /tmp/v_qs2.log 2>&1 &
  sleep 9
  expect "불일치 경고 출력" "incompatible QoS" bash -c 'cat /tmp/v_qs2.log'
  #  주의 — 경고 문구 자체에 "received" 가 들어 있다
  #  ("No messages will be received from it"). 반드시 [INFO] 줄만 센다
  GOT=$(grep -c '\[INFO\].*received:' /tmp/v_qs2.log)
  if [ "$GOT" -eq 0 ]; then
    ok "불일치 시 수신 0건"
  else
    ng "불일치 시 수신 0건" "실제로 ${GOT}줄 받았다"
  fi
  pkill -f qos_test_pub 2>/dev/null; pkill -f qos_test_sub 2>/dev/null
else
  ng "GitHub 에서 clone" "$(head -1 /tmp/v_clone.log)"
  skip "빌드·실행·QoS" "clone 실패로 이후 단계 건너뜀"
fi
sleep 2
rm -rf "$WS"

echo
echo "==================== 결과 ===================="
printf '%b\n' "$RESULTS"
echo
echo "  PASS $PASS  /  FAIL $FAIL  /  SKIP $SKIP"
[ "$FAIL" -eq 0 ] && echo "  ==> 문서대로 하면 된다 (합격)" || echo "  ==> 문서를 고쳐야 한다"
exit "$FAIL"
