#!/usr/bin/env bash
# measure_vrx.sh — 떠 있는 VRX 의 평균 RTF 와 화면 fps 를 잰다 (3주차 2-3)
#
#   bash measure_vrx.sh          # 60 초
#   bash measure_vrx.sh 120      # 120 초
#
#   RTF  : 1 초마다 /stats 를 한 번 읽어 (시뮬레이션 시각, 실제 시각) 을 모은다
#          평균 = 전체 구간의 시뮬레이션 시간 ÷ 실제 시간. 1 초 구간별 표준편차 · 최솟값도 낸다
#   화면 : GUI 가 한 장 그릴 때마다 내는 /gui/camera/pose 를 10 초 동안 센다
#   VRX 를 띄운 터미널과 다른 터미널에서 실행한다. 측정 자체가 CPU 를 거의 쓰지 않는다.

SECS="${1:-60}"
source /opt/ros/humble/setup.bash
TMP=$(mktemp -d)

if ! timeout 5 gz topic -e -t /stats -n 1 >/dev/null 2>&1; then
  echo "/stats 가 오지 않음 — VRX 가 떠 있는지 확인"; exit 1
fi

echo "측정 중 (${SECS} 초) ..."
FRAMES=$(timeout 10 gz topic -e -t /gui/camera/pose 2>/dev/null | grep -c "^position")
END=$((SECONDS + SECS))
while [ $SECONDS -lt $END ]; do
  timeout 3 gz topic -e -t /stats -n 1 --json-output 2>/dev/null >> "$TMP/stats.json"
  sleep 1
done

python3 - "$TMP/stats.json" "$FRAMES" <<'PY'
import json, sys, statistics as st
t = lambda d: float(d.get("sec", 0)) + float(d.get("nsec", 0)) * 1e-9
d = []
for line in open(sys.argv[1]):
    try:
        m = json.loads(line)
        d.append((t(m.get("simTime", {})), t(m.get("realTime", {}))))
    except ValueError:
        pass
if len(d) < 3:
    sys.exit("/stats 를 받지 못함")
r = [(d[j][0] - d[j-1][0]) / (d[j][1] - d[j-1][1]) for j in range(1, len(d)) if d[j][1] > d[j-1][1]]
sim, wall = d[-1][0] - d[0][0], d[-1][1] - d[0][1]
fps = int(sys.argv[2]) / 10
print(f"측정 구간      : 실제 {wall:.1f} s 동안 시뮬레이션 {sim:.1f} s 진행")
print(f"RTF 평균       : {sim / wall:.3f}")
print(f"RTF 구간별     : 표준편차 {st.pstdev(r):.3f} · 최솟값 {min(r):.3f} · 구간 {len(r)}개")
print(f"화면 fps       : {fps:.1f}" + ("   (GUI 없음 또는 멈춤)" if fps < 0.1 else ""))
if sim / wall < 0.5 or 0.1 <= fps < 10:
    print("판정           : 느림 — 3주차 2-3 의 run_vrx.sh lite 로 다시 띄울 것")
else:
    print("판정           : 정상")
PY
rm -rf "$TMP"
