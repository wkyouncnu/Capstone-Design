#!/usr/bin/env bash
# check_all.sh — 해양누리공원 월드에서 일곱 구간의 확인 예제를 차례로 돌리고 화면을 남긴다
#
#   준비 (터미널 세 개, 모두 같은 GZ_PARTITION·ROS_DOMAIN_ID)
#     1)  bash run_haeyang.sh lite shot          # 가제보 (캡처용 창 1760x980)
#     2)  bash ../TP_vrx_lite/rviz_term.sh       # Rviz2
#     3)  bash check_all.sh                      # 이 파일
#
#   한 구간만 :  bash check_all.sh gate | station | dock | search | station2 | obstacle | goal
#   녹화까지   :  REC=1 bash check_all.sh
#
#   TP_vrx_lite/check_all.sh 와 다른 곳
#     1) 지점표가 이 폴더의 goto.sh (해양누리공원 좌표) 다
#     2) 인지 예제(see_*.py)·캡처 도구(xcap.py)는 **TP_vrx_lite 것을 그대로 쓴다**
#        — 그 예제들은 센서 기준(배 앞 몇 m)으로만 판단하므로 월드가 바뀌어도 그대로 돈다.
#        딱 하나 see_station.py 만 부표 좌표가 필요해, --east/--north 로 새 좌표를 준다.
#     3) 항로추종 게이트가 8 쌍이 아니라 6 쌍이라 둘째 표본이 gate4 가 아니라 gate3 다
#
#   남는 것 (기본 $HOME/capstone_ws/hy_shots)
#     NN_<구간>_cam.png    카메라 영상 + 탐지 결과를 얹은 그림
#     NN_<구간>_cloud.png  포인트클라우드를 위에서 본 그림 (matplotlib)
#     NN_<구간>_gz.png     가제보 창        NN_<구간>_rviz.png  Rviz2 창
#     NN_<구간>.log        예제가 찍은 숫자 전부
#
#   주의
#     순간이동(goto.sh)은 **확인용**이다. 채점은 출발선에서 전구간 연속으로 간다
#     (경기규정-202611 6.2(2)).
#  set -u 는 쓰지 않는다 — ROS setup.bash 가 미정의 변수를 건드려 스크립트가 바로 죽는다
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERC="$HERE/../TP_vrx_lite"          # 인지 예제와 캡처 도구가 있는 곳
cd "$HERE"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-7}"
export GZ_PARTITION="${GZ_PARTITION:-hy1}"
export DISPLAY="${DISPLAY:-:0}"
export PYTHONPATH="$PERC:$PYTHONPATH"      # see_*.py 가 tp_percep.py 를 끌어 쓴다
source /opt/ros/humble/setup.bash

OUT="${OUT:-$HOME/capstone_ws/hy_shots}"
REC="${REC:-0}"
RECSEC="${RECSEC:-8}"
ONLY="${1:-all}"
mkdir -p "$OUT"

#  가제보 카메라를 배 뒤 15 m · 위 8 m 에 붙인다 (구간마다 다시 안 잡아도 된다)
gz service -s /gui/follow --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean \
   --timeout 3000 --req 'data: "wamv"' > /dev/null 2>&1
gz service -s /gui/follow/offset --reqtype gz.msgs.Vector3d --reptype gz.msgs.Boolean \
   --timeout 3000 --req 'x: -15, y: 0, z: 8' > /dev/null 2>&1

shot() {            # shot <번호_이름>
  python3 "$PERC/xcap.py" --name Gazebo --out "$OUT/$1_gz.png"   2>&1 | tail -1
  python3 "$PERC/xcap.py" --name RViz   --out "$OUT/$1_rviz.png" 2>&1 | tail -1
  if [ "$REC" = "1" ]; then
    python3 "$PERC/xcap.py" --name Gazebo --out "$OUT/$1_gz.mp4"   --sec "$RECSEC" 2>&1 | tail -1
    python3 "$PERC/xcap.py" --name RViz   --out "$OUT/$1_rviz.mp4" --sec "$RECSEC" 2>&1 | tail -1
  fi
}

run() {             # run <번호_이름> <지점> <명령...>
  local tag="$1" wp="$2"; shift 2
  echo
  echo "=============================================================="
  echo " $tag   지점 $wp"
  echo "=============================================================="
  bash goto.sh "$wp" 2>&1 | tail -2
  sleep 2
  ( "$@" ) 2>&1 | tee "$OUT/$tag.log"
  shot "$tag"
}

want() { [ "$ONLY" = "all" ] || [ "$ONLY" = "$1" ]; }

# ── 0. 출발선 ──────────────────────────────────────────────────────────
if want start; then
  run 00_start start python3 "$PERC/see_gate.py" --out "$OUT/00_start_cam.png"
fi

# ── 1. 항로추종 (게이트 6 쌍) ──────────────────────────────────────────
if want gate; then
  run 01_gate gate1 python3 "$PERC/see_gate.py" --out "$OUT/01_gate_cam.png"
  run 02_gate3 gate3 python3 "$PERC/see_gate.py" --out "$OUT/02_gate3_cam.png"
  [ "$REC" = "1" ] && python3 "$PERC/rec_cam.py" --sec "$RECSEC" --overlay gate \
      --out "$OUT/01_gate_cam.mp4" 2>&1 | tail -2
fi

# ── 2. 위치유지 WP1 (동 0 · 북 10) ─────────────────────────────────────
if want station; then
  run 03_wp1 wp1 python3 "$PERC/see_station.py" --east 0 --north 10 --sec 8
fi

# ── 3. 도킹 ────────────────────────────────────────────────────────────
#  표식 차례는 월드마다 다르다 — 해양누리공원 월드는 실제 사진대로 파랑·초록·빨강이다
TRUTH='서쪽 파랑 네모 · 가운데 초록 원형 · 동쪽 빨강 삼각형'
if want dock; then
  run 04_dock_cloud dock python3 "$PERC/see_dock_cloud.py" --out "$OUT/04_dock_cloud.png"
  ( python3 "$PERC/see_placard.py" --truth "$TRUTH" --out "$OUT/05_dock_cam.png" ) 2>&1 | tee "$OUT/05_dock_cam.log"
  shot 05_dock_cam
  run 06_dock_C dock_C python3 "$PERC/see_placard.py" --truth "$TRUTH" --out "$OUT/06_dock_C_cam.png"
  [ "$REC" = "1" ] && python3 "$PERC/rec_cam.py" --sec "$RECSEC" --overlay placard \
      --out "$OUT/05_dock_cam.mp4" 2>&1 | tail -2
fi

# ── 4. 탐색 ────────────────────────────────────────────────────────────
if want search; then
  run 07_search_red search_red python3 "$PERC/see_search.py" --out "$OUT/07_search_red_cam.png"
  run 08_search_grn search_grn python3 "$PERC/see_search.py" --out "$OUT/08_search_grn_cam.png"
  run 09_search_ylw search_ylw python3 "$PERC/see_search.py" --out "$OUT/09_search_ylw_cam.png"
  [ "$REC" = "1" ] && python3 "$PERC/rec_cam.py" --sec "$RECSEC" --overlay search \
      --out "$OUT/09_search_ylw_cam.mp4" 2>&1 | tail -2
fi

# ── 5. 위치유지 WP2 (동 -20 · 북 -14) ──────────────────────────────────
if want station2; then
  run 10_wp2 wp2 python3 "$PERC/see_station.py" --east -20 --north -14 --sec 8
fi

# ── 6. 장애물회피 ──────────────────────────────────────────────────────
if want obstacle; then
  run 11_obs_gate obs_gate   python3 "$PERC/see_obstacle_cloud.py" --out "$OUT/11_obs_gate_cloud.png"
  run 12_obs_front obs_front python3 "$PERC/see_obstacle_cloud.py" --out "$OUT/12_obs_front_cloud.png"
  run 13_obs_mid obs_mid     python3 "$PERC/see_obstacle_cloud.py" --out "$OUT/13_obs_mid_cloud.png"
fi

# ── 7. 종료 게이트 ─────────────────────────────────────────────────────
if want goal; then
  run 14_goal goal python3 "$PERC/see_gate.py" --out "$OUT/14_goal_cam.png"
fi

echo
echo "=============================================================="
echo " 끝. 남은 것 : $OUT"
ls -1 "$OUT" | sed 's/^/   /'
echo
echo " 가제보를 끌 때 :  bash ../TP_vrx_lite/stop_vrx.sh"
