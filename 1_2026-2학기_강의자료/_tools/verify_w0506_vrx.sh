#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# verify_w0506_vrx.sh — 5·6주차 VRX 절(W05 E-1 · W06 G-0 ~ G-5)을 문서 순서대로
#                       WSL 에서 실제로 실행해 검증한다. MATLAB 쪽은 스킬
#                       capstone-lecture-vault 의 references/fresh-clone-check.md 2장.
#
#   wsl -d Ubuntu-22.04 -- bash -lc \
#     "bash ~/Capstone-Design/1_2026-2학기_강의자료/_tools/verify_w0506_vrx.sh"
#
#   VRX 를 세 번 띄웠다 끈다. 약 6 분. 합격선 FAIL 0.
#   실험 중인 VRX 가 있으면 끈다 — 실험과 동시에 돌리지 말 것 (doc-verification.md 4장)
# ---------------------------------------------------------------------------
set +u
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  [PASS] $1"; }
ng() { FAIL=$((FAIL+1)); echo "  [FAIL] $1  -- $2"; }
expect() {                       # expect 이름 기대문자열 명령...
  local name=$1 want=$2; shift 2
  local out; out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -q -- "$want"; then ok "$name"
  else ng "$name" "기대: '$want' / 실제: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi
}

B=~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료
L3=$B/W03_vrx_lite; L6=$B/W06_vrx_lite
source /opt/ros/humble/setup.bash 2>/dev/null
source ~/vrx_ws/install/setup.bash 2>/dev/null
#  bash -lc 는 ~/.bashrc 를 끝까지 읽지 않는다 (비대화형이면 첫머리에서 return).
#  그래서 도메인은 ~/.bashrc 의 export 줄에서 직접 읽는다
DOM=$(grep -E '^export ROS_DOMAIN_ID=' ~/.bashrc | tail -1 | cut -d= -f2)
export ROS_DOMAIN_ID=${DOM:-0}

wait_topics() {                  # wait_topics 최소개수 — thrusters·ground_truth 줄 수
  local i n
  for i in $(seq 1 60); do
    n=$(ros2 topic list 2>/dev/null | grep -cE "thrusters|ground_truth")
    [ "$n" -ge "$1" ] && return 0; sleep 2
  done; return 1
}
launch() {                       # launch 폴더 스크립트 — 화면 없이 띄움 (headless)
  ( cd "$1" && setsid nohup bash "$2" headless > /tmp/verify_vrx.log 2>&1 < /dev/null & )
}

echo "==================== 5·6주차 VRX 검증 ===================="
echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"

echo "[저장소] 강의자료"
expect "강의자료 clone"          "Capstone-Design"  bash -c "cd ~/Capstone-Design && git remote -v"
expect "git pull"                "up to date\|Updating\|Fast-forward" bash -c "cd ~/Capstone-Design && git pull"
expect "ROS_DOMAIN_ID = 7"       "^7$"              bash -c "echo $ROS_DOMAIN_ID"
expect "W03 stop_vrx.sh 있음"    "stop_vrx.sh"      ls "$L3"
expect "WSLg 화면 정상"          "화면 정상"        bash "$L3/check_gui.sh"
expect "W06 폴더 열한 개"        "^11$"             bash -c "ls $L6 | wc -l"
expect "VRX 스폰 (원본 162/200)" "Model('wamv'"     grep -n "Model('wamv'" ~/vrx_ws/src/vrx/vrx_gz/launch/competition.launch.py

echo "[W05 E-1] 3주차 경량 모델"
expect "stop_vrx.sh 정리"        "끈 뒤: 0 개\|끄기 전: 0 개" bash "$L3/stop_vrx.sh"
#  run_vrx.sh 에는 headless 모드가 없다 — 문서 그대로 lite 로 띄운다 (WSLg 창이 뜸)
( cd "$L3" && setsid nohup bash run_vrx.sh > /tmp/verify_vrx.log 2>&1 < /dev/null & )
if wait_topics 5; then ok "W05 토픽 (thrusters 4 + ground_truth)"; else ng "W05 토픽" "120 초 안에 안 뜸"; fi
sleep 20
expect "W05 bow 토픽은 없음"     "^0$"              bash -c "ros2 topic list | grep -c bow"
expect "W05 RTF 출력"            "real_time_factor" bash -c "timeout 10 gz topic -e -t /stats -n 1"
expect "W05 오돔 주기 ~10 Hz"    "average rate: 9\." bash -c "timeout 6 ros2 topic hz /wamv/sensors/position/ground_truth_odometry"
expect "W05 정리"                "끈 뒤: 0 개\|끄기 전: 0 개" bash "$L3/stop_vrx.sh"

echo "[W06 G-0] 선수추진기 WAM-V"
expect "DRY=1 launch 명령"       "competition.launch.py" env DRY=1 bash "$L6/run_vrx_bow.sh"
expect "make_wamv_bow.sh"        "bow/thrust"       bash "$L6/make_wamv_bow.sh"
launch "$L6" run_vrx_bow.sh
if wait_topics 7; then ok "W06 토픽 (thrusters 6 + ground_truth)"; else ng "W06 토픽" "120 초 안에 안 뜸"; fi
sleep 15
expect "W06 bow/thrust"          "bow/thrust"       bash -c "ros2 topic list"

echo "[W06 G-4 · G-5] 넓은 물에서 측정"
expect "to_open_water.sh"        "넓은 물로 옮김"   bash "$L6/to_open_water.sh"
expect "measure_sway +250"       "횡 방향 맞음 · 요 유지 맞음 · 전진 억제 맞음" bash "$L6/measure_sway.sh" 250 10
expect "measure_sway -250"       "횡 방향 맞음 · 요 유지 맞음 · 전진 억제 맞음" bash "$L6/measure_sway.sh" -250 10
expect "measure_bow +500"        "우현(NED +y)"     bash "$L6/measure_bow.sh" 500 8
expect "W06 정리"                "끈 뒤: 0 개\|끄기 전: 0 개" bash "$L3/stop_vrx.sh"

echo
echo "합계: PASS $PASS · FAIL $FAIL"
[ "$FAIL" -eq 0 ]
