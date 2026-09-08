#!/usr/bin/env bash
# xclick.sh <창이름조각> <x,y> [<x,y> ...] — WSLg 창 안의 좌표를 클릭한다.
export DISPLAY=:0
NAME="$1"; shift
ID=$(xdotool search --name "$NAME" | tail -1)
if [ -z "$ID" ]; then echo "NOTFOUND: $NAME"; exit 2; fi
xdotool windowactivate "$ID" 2>/dev/null
sleep 1
for pt in "$@"; do
  X=${pt%,*}; Y=${pt#*,}
  xdotool mousemove --window "$ID" "$X" "$Y" click 1
  sleep 1.5
done
echo "CLICKED id=$ID : $*"
