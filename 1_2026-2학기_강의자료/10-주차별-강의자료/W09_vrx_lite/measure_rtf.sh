#!/usr/bin/env bash
# measure_rtf.sh — 라이다 판마다 RTF 와 발행 주기를 실제로 재서 표로 찍는다 (9주차 2-4)
#
#   bash measure_rtf.sh            # 네 판을 차례로 — none · ultralite · lite · full
#   bash measure_rtf.sh lite       # 한 판만
#   SEC=30 bash measure_rtf.sh     # 판마다 재는 시간 (기본 20 초)
#
#   재는 것 둘
#     RTF        모의가 실제 시간을 얼마나 따라가는가. 1.0 이면 1 초에 1 초를 민다.
#                0.5 면 절반 속도다 — 제어 주기가 설계대로 돌지 않는다는 뜻이다.
#     points Hz  라이다가 실제로 몇 번 발행하는가. 설계는 10 Hz 인데 못 따라가면
#                회피 로직이 낡은 장면을 보고 판단한다.
#
#   RTF 를 두 번 재는 까닭
#     구독자가 붙으면 점구름을 **받아서 푸는** 비용이 따로 든다. full 판은 한 번에
#     30,000 점 = 약 960 KB 다. 그래서 "아무도 안 볼 때" 와 "한 명이 볼 때" 를 나눠 잰다.
#     실제 데모는 뒤쪽 숫자로 돌아간다.
#
#   화면 없이(headless) 잰다 — 창을 띄우면 그리는 비용이 섞여 판끼리 비교가 안 된다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEC="${SEC:-20}"
WORLD="${WORLD:-stationkeeping_task}"
PTS=/wamv/sensors/lidars/lidar_wamv_sensor/points
LOG=/tmp/measure_rtf.log

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

GRADES=( "$@" )
[ ${#GRADES[@]} -eq 0 ] && GRADES=(none ultralite lite full)

urdf_of() {
  case "$1" in
    none) echo "$HERE/../W06_vrx_lite/wamv_bow_lite.urdf" ;;     # 6주차 배 그대로 — 라이다 없음
    *)    echo "$HOME/capstone_ws/wamv/wamv_ca_$1.urdf" ;;
  esac
}

#  gz 의 통계 토픽 이름은 월드마다 다르다 (/world/<이름>/stats). 찾아서 쓴다
find_stats() {
  for _ in $(seq 1 60); do
    t=$(gz topic -l 2>/dev/null | grep -m1 '/stats$') && [ -n "$t" ] && { echo "$t"; return 0; }
    sleep 2
  done
  return 1
}

#  real_time_factor 를 SEC 초 동안 모아 평균을 낸다. 첫 줄들은 아직 덜 자리잡았으므로 버린다
sample_rtf() {
  timeout "$1" gz topic -e -t "$ST" 2>/dev/null \
    | grep -o 'real_time_factor: [0-9.]*' | awk '{print $2}' \
    | awk 'NR>3 {s+=$1; n++} END {if(n>0) printf "%.2f", s/n; else printf "?"}'
}

printf '\n%-10s %8s %10s %10s %10s\n' 판 점/스캔 RTF_단독 RTF_구독중 points_Hz
printf '%s\n' "------------------------------------------------------------"

for G in "${GRADES[@]}"; do
  U="$(urdf_of "$G")"
  [ -f "$U" ] || { echo "$G: URDF 가 없음 ($U) — 먼저 make_wamv_ca.sh"; continue; }

  bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1

  nohup ros2 launch vrx_gz competition.launch.py world:="$WORLD" \
        urdf:="$U" headless:=true > "$LOG" 2>&1 &
  ST="$(find_stats)" || { echo "$G: gz 통계 토픽이 안 뜸 — $LOG 를 볼 것"; continue; }
  sleep 10                      # 물리가 자리잡기를 기다린다

  R1="$(sample_rtf "$SEC")"     # 아무도 안 볼 때

  HZF=/tmp/measure_hz.txt
  if grep -q 'gpu_ray\|gpu_lidar' "$U"; then
    timeout $((SEC+3)) ros2 topic hz "$PTS" --window 20 > "$HZF" 2>&1 &
    HZPID=$!
    sleep 3
    R2="$(sample_rtf "$SEC")"   # 한 명이 볼 때
    wait $HZPID 2>/dev/null
    HZ="$(grep -o 'average rate: [0-9.]*' "$HZF" | tail -1 | awk '{printf "%.2f", $3}')"
    [ -z "$HZ" ] && HZ="?"
    N="$(grep -o '<samples>[0-9.]*</samples>' "$U" | head -2 | grep -o '[0-9.]*' \
         | awk 'NR==1{a=$1} NR==2{b=$1} END{printf "%d", a*b}')"
  else
    R2="-"; HZ="-"; N=0
  fi

  printf '%-10s %8s %10s %10s %10s\n' "$G" "$N" "$R1" "$R2" "$HZ"
done

bash "$HERE/../W03_vrx_lite/stop_vrx.sh" >/dev/null 2>&1
printf '%s\n' "------------------------------------------------------------"
echo "RTF 1.00 = 실제 시간과 같은 속도.  points_Hz 설계값은 URDF 의 update_rate."
