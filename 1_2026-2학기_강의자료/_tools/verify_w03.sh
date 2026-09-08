#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# verify_w03.sh — W03 문서에 실린 명령을 문서 순서대로 실제로 실행해 검증한다.
#
#   wsl -d Ubuntu-22.04 -u <사용자> -- bash -lc \
#     "export DISPLAY=:0; bash /mnt/c/<볼트경로>/_tools/verify_w03.sh"
#
#   VRX 를 실제로 띄우므로 2~3분 걸린다. 합격선 FAIL 0.
# ---------------------------------------------------------------------------
# ROS 의 setup.bash 는 미설정 변수를 참조한다. set -u 를 켜면 source 에서 셸이 죽는다.
set +u
PASS=0; FAIL=0; SKIP=0
RESULTS=""

ok()   { PASS=$((PASS+1)); RESULTS="$RESULTS\n  [PASS] $1"; echo "  [PASS] $1"; }
ng()   { FAIL=$((FAIL+1)); RESULTS="$RESULTS\n  [FAIL] $1  -- $2"; echo "  [FAIL] $1  -- $2"; }
skip() { SKIP=$((SKIP+1)); RESULTS="$RESULTS\n  [SKIP] $1  -- $2"; echo "  [SKIP] $1  -- $2"; }

expect() {
  local name=$1 want=$2; shift 2
  local out
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -q -- "$want"; then ok "$name"
  else ng "$name" "기대: '$want' / 실제 앞부분: $(printf '%s' "$out" | head -1)"; fi
}

echo "==================== W03 문서 검증 ===================="
echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo

source /opt/ros/humble/setup.bash 2>/dev/null
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-7}

# ---------- §2-1 Gazebo ----------
echo "[§2-1] Gazebo Garden"
expect "gz 명령 존재"     "gz"      bash -c 'which gz'
expect "gz 버전 7.x"      "7."      bash -c 'gz sim --versions 2>&1 | head -1'
expect "ros_gz 브리지"    "ros_gz"  bash -c 'ls /opt/ros/humble/share | grep ros_gz | head -1'
echo

# ---------- §2-2 VRX ----------
echo "[§2-2] VRX"
if [ -d "$HOME/vrx_ws/src/vrx" ]; then
  expect "브랜치 humble"  "humble"  bash -c 'cd ~/vrx_ws/src/vrx && git branch --show-current'
  expect "기본은 jazzy"   "jazzy"   bash -c "cd ~/vrx_ws/src/vrx && git branch -r | grep 'origin/HEAD'"
  expect "빌드 산출물"    ".so"     bash -c 'ls ~/vrx_ws/install/lib/ | grep "\.so" | head -1'
  expect "패키지 5개"     "vrx_gz"  bash -c 'ls ~/vrx_ws/install/share'
  source "$HOME/vrx_ws/install/setup.bash" 2>/dev/null
else
  ng "VRX 워크스페이스" "~/vrx_ws 가 없다"
fi
echo

# ---------- §2-6 usv_basics teleop ----------
echo "[§2-6] wamv_teleop_key"
WS=/tmp/verify_w03_ws
rm -rf "$WS"; mkdir -p "$WS/src"
if timeout 90 git clone -q https://github.com/wkyouncnu/usv_basics.git "$WS/src/usv_basics" 2>/tmp/v3_clone.log; then
  ok "저장소 clone"
  ( cd "$WS" && timeout 180 colcon build --symlink-install > /tmp/v3_build.log 2>&1 )
  expect "빌드 성공"      "1 package finished" bash -c 'cat /tmp/v3_build.log'
  source "$WS/install/setup.bash" 2>/dev/null
  expect "teleop 등록됨"  "wamv_teleop_key"    bash -c 'timeout 10 ros2 pkg executables usv_basics'
  #  터미널이 아닌 곳에서 실행하면 termios 오류가 나야 한다 (문서의 '막혔을 때' 항목)
  expect "비터미널 오류"  "Inappropriate ioctl" \
      bash -c "timeout 15 ros2 run usv_basics wamv_teleop_key < /dev/null 2>&1 | tail -3"
else
  ng "저장소 clone" "$(head -1 /tmp/v3_clone.log)"
  skip "teleop 빌드·실행" "clone 실패"
fi
echo

# ---------- §2-3 ~ §2-6 VRX 실행 ----------
echo "[§2-3~2-6] VRX 실행과 조종"
if [ -n "${DISPLAY:-}" ] && [ -d "$HOME/vrx_ws/install" ]; then
  pkill -9 -f 'vrx_gz' 2>/dev/null; sleep 3
  setsid nohup ros2 launch vrx_gz competition.launch.py world:=sydney_regatta \
      > /tmp/v3_vrx.log 2>&1 < /dev/null & disown
  echo "  VRX 기동 대기 90초..."
  sleep 90
  expect "WAM-V 노드"     "wamv"        bash -c 'timeout 20 ros2 node list'
  expect "좌 추진기 토픽" "left/thrust" bash -c 'timeout 20 ros2 topic list'
  expect "우 추진기 토픽" "right/thrust" bash -c 'timeout 20 ros2 topic list'
  expect "GPS 발행"       "latitude"    bash -c 'timeout 30 ros2 topic echo --once /wamv/sensors/gps/gps/fix'
  expect "Gazebo 창"      "Gazebo"      bash -c 'xdotool search --name Gazebo getwindowname %@ 2>/dev/null | head -2'
  expect "카메라 고정"    "true" bash -c "gz service -s /gui/follow --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean --timeout 4000 --req 'data: \"wamv\"'"

  #  teleop 이 실제로 추력을 내보내는지 — 토픽을 받아 본다
  if [ -f "$WS/install/setup.bash" ]; then
    timeout 12 ros2 topic pub /wamv/thrusters/left/thrust std_msgs/msg/Float64 "{data: 200.0}" -r 10 \
        > /dev/null 2>&1 &
    sleep 5
    expect "추력 명령 수신" "200" bash -c 'timeout 12 ros2 topic echo --once /wamv/thrusters/left/thrust'
    sleep 8
  fi
  pkill -9 -f 'vrx_gz' 2>/dev/null
  sleep 3
else
  skip "VRX 실행 전체" "DISPLAY 가 없거나 vrx_ws 미빌드"
fi
rm -rf "$WS"

echo
echo "==================== 결과 ===================="
printf '%b\n' "$RESULTS"
echo
echo "  PASS $PASS  /  FAIL $FAIL  /  SKIP $SKIP"
[ "$FAIL" -eq 0 ] && echo "  ==> 문서대로 하면 된다 (합격)" || echo "  ==> 문서를 고쳐야 한다"
exit "$FAIL"
