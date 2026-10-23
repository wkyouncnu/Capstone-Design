#!/usr/bin/env bash
# check_gui.sh — WSL 의 화면(WSLg)이 Windows 로 창을 내보낼 수 있는지 본다 (3·5·6주차)
#
#   bash check_gui.sh        # 정상이면 "화면 정상", 아니면 고치는 법을 찍고 1 을 돌려줌
#
#   증상 (2026-10-23 노트북 실측)
#     run_vrx.sh 를 치면 로그는 쏟아지고 gz sim gui 프로세스도 떠 있는데
#     **Gazebo 창이 Windows 화면에 나타나지 않는다.** 오류 메시지는 없다.
#   원인
#     Windows 쪽에서 리눅스 창을 그려 주는 프로그램 msrdc.exe 가 30 초마다
#     꺼졌다 다시 켜지기를 반복하는 상태 (WSLg 가 꼬임). Gazebo 만이 아니라
#     리눅스 창이 전부 안 뜬다. 노트북을 재우거나 오래 켜 두면 생긴다
#   해결
#     Windows PowerShell 에서  wsl --shutdown  → 터미널을 새로 열고 다시 띄움
#
#   판정: /mnt/wslg/stderr.log (WSL 을 켤 때마다 새로 씀) 에 msrdc.exe 가
#         끝났다는 줄이 3 번 이상이면 반복 상태로 본다. 정상이면 0 번이다.

LOG=${WSLG_LOG:-/mnt/wslg/stderr.log}   # 시험할 때만 WSLG_LOG=가짜파일 로 바꿈

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  echo "화면 없음: DISPLAY 가 비어 있음 — WSLg 가 꺼진 WSL 이거나 원격 셸임"
  echo "  Windows 11 의 WSL 2 인지 확인:  PowerShell 에서  wsl --version  (WSLg 버전이 찍혀야 함)"
  exit 1
fi

if [ -r "$LOG" ]; then
  n=$(grep -c 'exited with status' "$LOG" 2>/dev/null)
  if [ "${n:-0}" -ge 3 ]; then
    echo "화면 이상: Windows 쪽 창 표시기(msrdc.exe)가 $n 번 다시 켜졌음 → Gazebo 창이 안 뜸"
    echo "  고치는 법: Windows PowerShell 에서  wsl --shutdown"
    echo "             → 이 터미널을 닫고 새로 연 뒤 다시 실행 (30 초쯤 걸림)"
    exit 1
  fi
fi
echo "화면 정상 (DISPLAY=$DISPLAY, 창 표시기 재시작 ${n:-0} 번)"
exit 0
