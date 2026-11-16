#!/usr/bin/env bash
# stop_vrx.sh — 남은 가제보·브리지를 끈다
#
#   bash stop_vrx.sh         # 끈다
#   bash stop_vrx.sh check   # 무엇이 떠 있는지만 본다
#
#   내용은 3주차 것을 그대로 쓴다 — 한 군데만 두고 가리킨다.
#   왜 반드시 끄는가 : 남은 gz sim 이 메모리를 62 GB 까지 먹고 OOM 을 부른다.
#
#   경고 — 이 스크립트는 **프로세스 이름으로** 끈다. 칸(GZ_PARTITION)을 보지 않는다.
#   가제보를 둘 띄워 두었다면 남의 것까지 끈다. 그럴 때는 띄운 터미널에서 Ctrl+C 를 쓴다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$HERE/../../10-주차별-강의자료/W03_vrx_lite/stop_vrx.sh" "$@"
