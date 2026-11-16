#!/usr/bin/env bash
# rec_run.sh — 한 지점에서 배를 실제로 움직이며 가제보·Rviz2·카메라를 동시에 녹화한다
#
#   bash rec_run.sh <지점> <태그> [초] [추력N] [오버레이]
#
#   보기
#     bash rec_run.sh gate1     01_gate     12  120  gate
#     bash rec_run.sh dock      05_dock     10   80  placard
#     bash rec_run.sh obs_front 12_obs      12  100  none
#     bash rec_run.sh wp1       03_wp1      10    0  none     # 추력 0 = 위치유지(정지) 녹화
#
#   남는 것 ($HOME/capstone_ws/tp_shots)
#     <태그>_gz.mp4    가제보 창      <태그>_gz.png    그 가운데 장면
#     <태그>_rviz.mp4  Rviz2 창       <태그>_rviz.png
#     <태그>_cam.mp4   카메라 영상 + 탐지 결과를 얹은 것
#
#   왜 추력을 주는가
#     순간이동만 해 놓고 찍으면 파도만 흔들리는 정지 화면이 된다.
#     좌·우 추진기에 같은 추력을 주어 **직진**시키면 게이트가 다가오고
#     포인트클라우드가 갱신되는 것이 영상에 남는다. 조타는 하지 않는다 —
#     유도·제어는 Simulink/Stateflow 쪽 몫이고 여기는 인지 확인용이다.
#
#   주의
#     창 셋을 동시에 뜯으면 각각 1~2 Hz 로 떨어진다. xcap.py 가 실제 속도로
#     기록하므로 영상 길이는 실제 시간과 같다 (빨리감기가 아니다).

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-7}"
export GZ_PARTITION="${GZ_PARTITION:-tp1}"
export DISPLAY="${DISPLAY:-:0}"
source /opt/ros/humble/setup.bash

OUT="${OUT:-$HOME/capstone_ws/tp_shots}"
mkdir -p "$OUT"

WP="${1:?지점 이름이 필요하다 — bash goto.sh 로 목록을 본다}"
TAG="${2:?태그가 필요하다 — 파일 이름이 된다}"
SEC="${3:-10}"
THRUST="${4:-100}"
OVER="${5:-none}"

echo "지점 $WP · 태그 $TAG · $SEC 초 · 추력 ${THRUST} N · 오버레이 $OVER"
bash goto.sh "$WP" | tail -1

#  추진기 — 좌·우에 같은 값을 주어 직진시킨다 (선수추진기는 0)
PIDS=()
if [ "${THRUST%.*}" != "0" ]; then
  for t in left right; do
    ros2 topic pub -r 10 "/wamv/thrusters/$t/thrust" std_msgs/msg/Float64 \
      "{data: $THRUST}" > /dev/null 2>&1 &
    PIDS+=($!)
  done
  echo "추진기 작동 — 좌·우 ${THRUST} N"
fi

#  창 둘 + 카메라를 한꺼번에 뜯는다
python3 xcap.py --name Gazebo --sec "$SEC" --out "$OUT/${TAG}_gz.mp4"   > "$OUT/${TAG}_rec_gz.log" 2>&1 &
G=$!
python3 xcap.py --name RViz   --sec "$SEC" --out "$OUT/${TAG}_rviz.mp4" > "$OUT/${TAG}_rec_rviz.log" 2>&1 &
R=$!
python3 rec_cam.py --sec "$SEC" --overlay "$OVER" --out "$OUT/${TAG}_cam.mp4" > "$OUT/${TAG}_rec_cam.log" 2>&1 &
C=$!
wait $G $R $C

#  추진기를 끄고 타력을 죽인다 — 다음 지점으로 순간이동하기 전에 꼭 한다
for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
if [ ${#PIDS[@]} -gt 0 ]; then
  for t in left right; do
    ros2 topic pub -1 "/wamv/thrusters/$t/thrust" std_msgs/msg/Float64 "{data: 0.0}" > /dev/null 2>&1
  done
  echo "추진기 정지"
fi

for f in gz rviz cam; do
  echo "── $f ──"
  grep -E "뜯어낸|받은|저장|대표" "$OUT/${TAG}_rec_$f.log" | sed 's/^/   /'
done
