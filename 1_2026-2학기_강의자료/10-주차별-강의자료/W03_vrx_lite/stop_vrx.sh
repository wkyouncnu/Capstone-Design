#!/usr/bin/env bash
# stop_vrx.sh — 떠 있는 VRX · Gazebo · 브리지를 모두 끈다 (3주차 2-3, 5·6주차 VRX 실습)
#
#   bash stop_vrx.sh          # 끄고, 남은 것이 없는지 확인
#   bash stop_vrx.sh check    # 끄지 않고 떠 있는 것만 보여 줌
#
#   언제 쓰는가
#     - 실험을 새로 시작하기 전 (실험마다 VRX 를 다시 띄운다)
#     - 터미널을 Ctrl+C 없이 닫았을 때 — gz sim server 가 고아로 남는다
#     - 배가 두 척 보이거나, 토픽 값이 튀거나, RTF 가 갑자기 반으로 떨어질 때
#
#   왜 두 번 끄는가 (2026-10-16 노트북 실측)
#     고아가 된 gz sim server 와 parameter_bridge 는 보통의 종료 신호(TERM)를
#     무시하고 남았다. 그래서 TERM 으로 3 초 기다린 뒤 남은 것을 KILL 로 끈다.
#
#   패턴의 첫 글자를 [ ] 로 감싼 까닭 — pkill 이 자기 명령줄을 잡아 이 셸이 먼저 죽지 않게

PAT='[g]z sim|[v]rx_gz|[v]rx_ros|[r]os_gz_bridge|[p]arameter_bridge|[r]uby .*gz|[m]onitor_sim|[r]os2 launch vrx_gz'

show() { pgrep -af "$PAT" | cut -c1-110; }

if [ "$1" = "check" ]; then
  n=$(pgrep -f "$PAT" | wc -l)
  echo "떠 있는 VRX 관련 프로세스: $n 개"
  show
  exit 0
fi

n0=$(pgrep -f "$PAT" | wc -l)
echo "끄기 전: $n0 개"
[ "$n0" -eq 0 ] && { echo "떠 있는 것이 없음 — 바로 띄우면 됨"; exit 0; }

pkill -TERM -f "$PAT"; sleep 3
n1=$(pgrep -f "$PAT" | wc -l)
if [ "$n1" -gt 0 ]; then
  echo "TERM 뒤 남은 것: $n1 개 → KILL"
  pkill -KILL -f "$PAT"; sleep 1
fi
n2=$(pgrep -f "$PAT" | wc -l)
if [ "$n2" -eq 0 ]; then
  echo "끈 뒤: 0 개 — 정리 완료"
else
  echo "끈 뒤에도 $n2 개 남음:"; show
  echo "WSL 을 통째로 다시 시작: Windows PowerShell 에서  wsl --shutdown"
  exit 1
fi
