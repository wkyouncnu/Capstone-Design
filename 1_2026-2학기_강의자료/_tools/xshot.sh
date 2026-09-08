#!/usr/bin/env bash
# xshot.sh <창이름조각> <저장경로> [폭 높이]
# WSLg 안에서 X 창을 직접 캡처한다. Windows 쪽 합성 문제를 피한다.
export DISPLAY=:0
NAME="$1"; OUT="$2"; W="${3:-1500}"; H="${4:-900}"

ID=$(xdotool search --name "$NAME" | tail -1)
if [ -z "$ID" ]; then echo "NOTFOUND: $NAME"; exit 2; fi

xdotool windowsize "$ID" "$W" "$H"
xdotool windowactivate "$ID" 2>/dev/null
sleep 2
import -window "$ID" "$OUT"
echo "SAVED $OUT  id=$ID"
identify "$OUT" | head -1
