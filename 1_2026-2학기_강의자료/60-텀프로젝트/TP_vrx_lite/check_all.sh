#!/usr/bin/env bash
# check_all.sh — 일곱 구간의 확인 예제를 순서대로 돌리고 화면을 남긴다
#
#   준비 (터미널 세 개)
#     1)  bash run_vrx_term.sh gui          # 가제보
#     2)  bash rviz_term.sh                 # Rviz2
#     3)  bash check_all.sh                 # 이 파일
#
#   한 구간만 :  bash check_all.sh gate | station | dock | search | obstacle
#   녹화까지   :  REC=1 bash check_all.sh
#
#   남는 것 (기본 $HOME/capstone_ws/tp_shots)
#     NN_<구간>_cam.png    카메라 영상 + 탐지 결과를 얹은 그림
#     NN_<구간>_cloud.png  포인트클라우드 위에서 본 그림 (matplotlib)
#     NN_<구간>_gz.png     가제보 창
#     NN_<구간>_rviz.png   Rviz2 창
#     NN_<구간>.log        예제가 찍은 숫자 전부
#     REC=1 이면 _gz.mp4 · _rviz.mp4 · _cam.mp4 도 남는다
#
#   주의
#     가제보를 띄운 터미널과 GZ_PARTITION·ROS_DOMAIN_ID 가 같아야 한다.
#     순간이동(goto.sh)은 **확인용**이다. 채점은 출발선에서 전구간 연속으로 간다
#     (경기규정-202611 6.2(2)).
#  set -u 는 쓰지 않는다 — ROS setup.bash 가 미정의 변수를 건드려 스크립트가 바로 죽는다
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-7}"
export GZ_PARTITION="${GZ_PARTITION:-tp1}"
export DISPLAY="${DISPLAY:-:0}"
source /opt/ros/humble/setup.bash

OUT="${OUT:-$HOME/capstone_ws/tp_shots}"
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
  python3 xcap.py --name Gazebo --out "$OUT/$1_gz.png"   2>&1 | tail -1
  python3 xcap.py --name RViz   --out "$OUT/$1_rviz.png" 2>&1 | tail -1
  if [ "$REC" = "1" ]; then
    python3 xcap.py --name Gazebo --out "$OUT/$1_gz.mp4"   --sec "$RECSEC" 2>&1 | tail -1
    python3 xcap.py --name RViz   --out "$OUT/$1_rviz.mp4" --sec "$RECSEC" 2>&1 | tail -1
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
  run 00_start start python3 see_gate.py --out "$OUT/00_start_cam.png"
fi

# ── 1. 항로추종 ────────────────────────────────────────────────────────
if want gate; then
  run 01_gate gate1 python3 see_gate.py --out "$OUT/01_gate_cam.png"
  run 02_gate4 gate4 python3 see_gate.py --out "$OUT/02_gate4_cam.png"
  [ "$REC" = "1" ] && python3 rec_cam.py --sec "$RECSEC" --overlay gate \
      --out "$OUT/01_gate_cam.mp4" 2>&1 | tail -2
fi

# ── 2. 위치유지 WP1 ────────────────────────────────────────────────────
if want station; then
  run 03_wp1 wp1 python3 see_station.py --wp wp1 --sec 8
fi

# ── 3. 도킹 ────────────────────────────────────────────────────────────
if want dock; then
  run 04_dock_cloud dock python3 see_dock_cloud.py --out "$OUT/04_dock_cloud.png"
  ( python3 see_placard.py --out "$OUT/05_dock_cam.png" ) 2>&1 | tee "$OUT/05_dock_cam.log"
  shot 05_dock_cam
  run 06_dock_C dock_C python3 see_placard.py --out "$OUT/06_dock_C_cam.png"
  [ "$REC" = "1" ] && python3 rec_cam.py --sec "$RECSEC" --overlay placard \
      --out "$OUT/05_dock_cam.mp4" 2>&1 | tail -2
fi

# ── 4. 탐색 ────────────────────────────────────────────────────────────
if want search; then
  run 07_search_red search_red python3 see_search.py --out "$OUT/07_search_red_cam.png"
  run 08_search_grn search_grn python3 see_search.py --out "$OUT/08_search_grn_cam.png"
  run 09_search_ylw search_ylw python3 see_search.py --out "$OUT/09_search_ylw_cam.png"
  [ "$REC" = "1" ] && python3 rec_cam.py --sec "$RECSEC" --overlay search \
      --out "$OUT/09_search_ylw_cam.mp4" 2>&1 | tail -2
fi

# ── 5. 위치유지 WP2 ────────────────────────────────────────────────────
if want station2; then
  run 10_wp2 wp2 python3 see_station.py --wp wp2 --sec 8
fi

# ── 6. 장애물회피 ──────────────────────────────────────────────────────
if want obstacle; then
  run 11_obs_gate obs_gate  python3 see_obstacle_cloud.py --out "$OUT/11_obs_gate_cloud.png"
  run 12_obs_front obs_front python3 see_obstacle_cloud.py --out "$OUT/12_obs_front_cloud.png"
  run 13_obs_mid obs_mid    python3 see_obstacle_cloud.py --out "$OUT/13_obs_mid_cloud.png"
fi

# ── 7. 종료 게이트 ─────────────────────────────────────────────────────
if want goal; then
  run 14_goal goal python3 see_gate.py --out "$OUT/14_goal_cam.png"
fi

echo
echo "=============================================================="
echo " 끝. 남은 것 : $OUT"
ls -1 "$OUT" | sed 's/^/   /'
echo
echo " 가제보를 끌 때 :  bash stop_vrx.sh   (남은 gz sim 이 메모리를 60 GB 까지 먹는다)"
