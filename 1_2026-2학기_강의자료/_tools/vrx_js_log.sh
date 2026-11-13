#!/usr/bin/env bash
#  가제보의 조인트 각도를 파일로 받는다 (Simulink 가 도는 동안 바깥에서)
#
#    bash vrx_js_log.sh <받을 초> <출력 파일> [몇 줄에 한 번] [도메인]
#
#  왜 필요한가
#    Simulink 가 sim() 으로 도는 동안 MATLAB 은 묶여 있어 토픽을 못 읽는다.
#    그래서 각도 실측은 **바깥에서** 받아 둔다. 끝난 뒤 파일을 읽어 견준다.
#
#  한 줄의 꼴 — 좌현 조인트[rad], 우현 조인트[rad]
#    시각은 적지 않는다. timeout 이 정확히 <받을 초> 동안만 받으므로, 읽는
#    쪽에서 linspace(0, 받을초, 줄수) 로 되돌린다 (일정 간격 표본)
#    조인트 순서는 /wamv/joint_states 가 정한 것이다 (3 번째·5 번째)
#      1 gps  2 imu  3 left_chassis_engine  4 left_propeller
#      5 right_chassis_engine  6 right_propeller
#  set -u 를 쓰지 않는다 — ROS 의 setup.bash 가 미정의 변수를 읽어 **멈춘다**
#    (AMENT_TRACE_SETUP_FILES: unbound variable)
DUR=${1:-30}
OUT=${2:-/tmp/a3_js.txt}
DEC=${3:-20}
DOM=${4:-7}

source /opt/ros/humble/setup.bash
#  도메인을 **반드시** 준다 — 비대화형 셸은 .bashrc 를 건너뛰어 기본값 0 이 된다.
#    도메인이 다르면 토픽은 보이지 않고, 오류도 없이 빈 파일만 남는다
export ROS_DOMAIN_ID=$DOM
: > "$OUT"

timeout "$DUR" ros2 topic echo --csv --field position /wamv/joint_states 2>/dev/null \
  | sed -u -E 's/.*\[//; s/\].*//' \
  | awk -F', *' -v dec="$DEC" 'NR % dec == 0 { printf "%.6f,%.6f\n", $3, $5 }' >> "$OUT"
