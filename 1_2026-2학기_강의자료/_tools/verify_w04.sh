#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# verify_w04.sh — W04 문서에 실린 명령을 문서 순서대로 실제로 실행해 검증한다.
#
#   wsl -d Ubuntu-22.04 -u <사용자> -- bash -lc \
#     "export DISPLAY=:0; bash /mnt/c/<볼트경로>/_tools/verify_w04.sh"
#
#   VRX 를 두 번 띄우므로 5분 안팎 걸린다. 합격선 FAIL 0.
# ---------------------------------------------------------------------------
# ROS 의 setup.bash 는 미설정 변수를 참조한다. set -u 를 켜면 source 에서 셸이 죽는다.
set +u
PASS=0; FAIL=0; SKIP=0
RESULTS=""

ok()   { PASS=$((PASS+1)); RESULTS="$RESULTS\n  [PASS] $1"; echo "  [PASS] $1"; }
ng()   { FAIL=$((FAIL+1)); RESULTS="$RESULTS\n  [FAIL] $1  -- $2"; echo "  [FAIL] $1  -- $2"; }
skip() { SKIP=$((SKIP+1)); RESULTS="$RESULTS\n  [SKIP] $1  -- $2"; echo "  [SKIP] $1  -- $2"; }

#  ROS 2 는 명령을 띄운 뒤 발행자를 '발견'하는 데 시간이 걸린다.
#  한 번 실패했다고 문서가 틀린 것이 아니므로 세 번까지 다시 본다.
expect() {
  local name=$1 want=$2; shift 2
  local out i
  for i in 1 2 3; do
    out=$("$@" 2>&1)
    if printf '%s' "$out" | grep -q -- "$want"; then ok "$name"; return; fi
    sleep 6
  done
  ng "$name" "기대: '$want' / 실제 앞부분: $(printf '%s' "$out" | head -1)"
}

echo "==================== W04 문서 검증 ===================="
echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo

source /opt/ros/humble/setup.bash 2>/dev/null
source "$HOME/vrx_ws/install/setup.bash" 2>/dev/null
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-7}

# ---------- §2-1 파일 구조 ----------
echo "[§2-1] VRX 파일 구조"
expect "센서 컴포넌트 폴더" "camera" \
  bash -c 'ls ~/vrx_ws/src/vrx/vrx_urdf/wamv_gazebo/urdf/components/'
expect "추진기 xacro"      "thruster" \
  bash -c 'ls ~/vrx_ws/src/vrx/vrx_urdf/wamv_gazebo/urdf/thrusters/'
echo

# ---------- §2-6 과제 월드 ----------
echo "[§2-6] 과제 월드 목록"
expect "정지유지 월드"   "stationkeeping_task" bash -c 'ls ~/vrx_ws/src/vrx/vrx_gz/worlds/'
expect "웨이포인트 월드" "wayfinding_task"     bash -c 'ls ~/vrx_ws/src/vrx/vrx_gz/worlds/'
expect "도킹 월드"       "scan_dock_deliver"   bash -c 'ls ~/vrx_ws/src/vrx/vrx_gz/worlds/'
expect "조이스틱 스크립트" "usv_joy_teleop"    bash -c 'ls ~/vrx_ws/src/vrx/vrx_gz/launch/'
echo

if [ -z "${DISPLAY:-}" ] || [ ! -d "$HOME/vrx_ws/install" ]; then
  skip "VRX 실행 전체" "DISPLAY 가 없거나 vrx_ws 미빌드"
else

# ---------- 과제 월드를 띄운다 ----------
echo "[§2-6] 과제 월드 실행 (stationkeeping_task)"
pkill -9 -f '[c]ompetition.launch' 2>/dev/null; pkill -9 -f '[g]z-sim' 2>/dev/null; pkill -9 -f '[p]arameter_bridge' 2>/dev/null; rm -f /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* 2>/dev/null; sleep 4
ros2 daemon stop > /dev/null 2>&1; sleep 2
setsid nohup ros2 launch vrx_gz competition.launch.py world:=stationkeeping_task \
    > /tmp/v4_sk.log 2>&1 < /dev/null & disown
echo "  기동 대기 95초..."
sleep 95
expect "task/info 발행"   "task"            bash -c 'timeout 25 ros2 topic list | grep vrx/task'
expect "과제 이름"        "stationkeeping"  bash -c 'timeout 30 ros2 topic echo --once /vrx/task/info'
expect "상태 항목"        "state"           bash -c 'timeout 30 ros2 topic echo --once /vrx/task/info'
expect "점수 항목"        "score"           bash -c 'timeout 30 ros2 topic echo --once /vrx/task/info'
expect "충돌 항목"        "num_collisions"  bash -c 'timeout 30 ros2 topic echo --once /vrx/task/info'
expect "바람 방향"        "data"            bash -c 'timeout 25 ros2 topic echo --once /vrx/debug/wind/direction'
expect "goal 은 VOLATILE" "VOLATILE"        bash -c 'timeout 25 ros2 topic info /vrx/stationkeeping/goal --verbose'
pkill -9 -f '[c]ompetition.launch' 2>/dev/null; pkill -9 -f '[g]z-sim' 2>/dev/null; pkill -9 -f '[p]arameter_bridge' 2>/dev/null; rm -f /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* 2>/dev/null; sleep 5
echo

# ---------- sydney_regatta 로 센서·bag ----------
echo "[§2-3 · §2-7] 센서와 rosbag"
ros2 daemon stop > /dev/null 2>&1; sleep 2
setsid nohup ros2 launch vrx_gz competition.launch.py world:=sydney_regatta \
    > /tmp/v4_sr.log 2>&1 < /dev/null & disown
echo "  기동 대기 95초..."
sleep 95
expect "GPS 위도"    "latitude"  bash -c 'timeout 30 ros2 topic echo --once /wamv/sensors/gps/gps/fix'
expect "IMU 자세"    "orientation" bash -c 'timeout 30 ros2 topic echo --once /wamv/sensors/imu/imu/data'
expect "LiDAR 토픽"  "scan"      bash -c 'timeout 25 ros2 topic list | grep lidar'
expect "발행자 1개"  "Publisher count: 1" \
  bash -c 'timeout 25 ros2 topic info /wamv/sensors/gps/gps/fix --verbose'

rm -rf /tmp/v4_bag
timeout 22 ros2 bag record -o /tmp/v4_bag \
  /wamv/sensors/gps/gps/fix /wamv/sensors/imu/imu/data > /tmp/v4_rec.log 2>&1
expect "기록 시작"   "Recording"  bash -c 'cat /tmp/v4_rec.log'
expect "GPS 구독"    "gps/gps/fix" bash -c 'cat /tmp/v4_rec.log'
expect "bag 정보"    "Messages:"  bash -c 'timeout 30 ros2 bag info /tmp/v4_bag'
expect "sqlite3 저장" "sqlite3"   bash -c 'timeout 30 ros2 bag info /tmp/v4_bag'

pkill -9 -f '[c]ompetition.launch' 2>/dev/null; pkill -9 -f '[g]z-sim' 2>/dev/null; pkill -9 -f '[p]arameter_bridge' 2>/dev/null; rm -f /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* 2>/dev/null; sleep 5
ros2 daemon stop > /dev/null 2>&1; sleep 2

#  시뮬레이터를 껐는데도 재생되는지 — 이것이 bag 의 핵심
echo "  시뮬레이터를 끈 상태에서 재생 확인..."
ros2 daemon start > /dev/null 2>&1; sleep 3
setsid nohup ros2 bag play /tmp/v4_bag --loop > /tmp/v4_play.log 2>&1 < /dev/null & disown
sleep 12
expect "시뮬 없이 재생" "latitude" bash -c 'timeout 25 ros2 topic echo --once /wamv/sensors/gps/gps/fix'
pkill -9 -f '[b]ag play' 2>/dev/null
rm -rf /tmp/v4_bag

fi

echo
echo "==================== 결과 ===================="
printf '%b\n' "$RESULTS"
echo
echo "  PASS $PASS  /  FAIL $FAIL  /  SKIP $SKIP"
[ "$FAIL" -eq 0 ] && echo "  ==> 문서대로 하면 된다 (합격)" || echo "  ==> 문서를 고쳐야 한다"
exit "$FAIL"
