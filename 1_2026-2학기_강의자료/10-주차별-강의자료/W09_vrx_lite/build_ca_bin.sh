#!/usr/bin/env bash
# build_ca_bin.sh — 9주차 파이썬 셋을 **실행 파일**로 만든다 (교수용. 학생은 치지 않는다)
#
#   bash build_ca_bin.sh
#
#   왜 필요한가
#     회피기(collision_avoidance_enu.py) · ca_bridge.py · ca_viz.py 의 **소스는 저장소에 올리지 않는다**
#     (.gitignore). 학생은 git pull 로 bin/ 의 실행 파일 셋만 받고, run_ca_nodes.sh 가 그것을 띄운다.
#     소스가 있는 PC(교수 PC)에서는 run_ca_nodes.sh 가 소스를 그대로 띄운다.
#
#   만드는 것
#     bin/vfh_avoider   <- collision_avoidance_enu.py   (이 폴더에 없으면 ~/vrx_ws/src/vrx_control 에서 찾는다)
#     bin/ca_bridge     <- ca_bridge.py
#     bin/ca_viz        <- ca_viz.py
#
#   만드는 법 — Cython 으로 C 로 바꾼 뒤 gcc 로 묶는다 (파이썬 해석기를 품은 ELF 실행 파일)
#     - 실행에는 libpython3.10 이 필요하다. ROS 2 Humble(rclpy)이 이미 끌고 들어온다
#     - rclpy · numpy · matplotlib 은 실행할 때 그 PC 의 것을 쓴다 (묶어 넣지 않는다)
#     - 그래서 Ubuntu 22.04 · x86_64 · Python 3.10 에서만 돈다 — 이 과목의 환경 그대로다
#
#   준비물 — 없다. Cython 은 처음 돌릴 때 ~/.cache/w09_cython 에 스스로 받는다 (인터넷 필요)
#            gcc 와 python3.10-dev 는 ROS 설치에 딸려 온다
#
#   소스를 고쳤으면 이 스크립트를 다시 돌리고 bin/ 을 커밋한다.

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#  한글 경로·/mnt/c 위에서는 gcc 가 느리고 권한이 섞인다 — 리눅스 쪽 임시 폴더에서 만든다
WORK="${WORK:-$HOME/.cache/w09_ca_build}"
OUT="${OUT:-$HERE/bin}"

AVO="$HERE/collision_avoidance_enu.py"
[ -f "$AVO" ] || AVO="$HOME/vrx_ws/src/vrx_control/vrx_control/collision_avoidance_enu.py"

#  Cython 은 **따로 둔 폴더**에 깔아 쓴다. ~/.local 에 다른 numpy 가 깔린 PC 에서는
#  Cython 이 pythran -> scipy 를 들이다가 numpy 판이 안 맞아 죽는다 (2026-11-17 노트북 실측).
#  그래서 사용자 폴더(~/.local)를 끄고(PYTHONNOUSERSITE) 이 폴더만 본다
CY="$HOME/.cache/w09_cython"
[ -d "$CY/Cython" ] || { echo "Cython 을 $CY 에 받는다 (한 번만)"; pip3 install -q --target "$CY" cython; }
cy() { PYTHONNOUSERSITE=1 PYTHONPATH="$CY" python3 -m cython "$@"; }
for f in "$AVO" "$HERE/ca_bridge.py" "$HERE/ca_viz.py"; do
  [ -f "$f" ] || { echo "소스가 없음: $f"; exit 1; }
done

rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"
INC="$(python3-config --includes)"
LNK="$(python3-config --embed --ldflags)"

build() {   # $1 = 소스  $2 = 실행 파일 이름
  local src="$1" name="$2"
  cp "$src" "$WORK/$name.py"
  ( cd "$WORK"
    #  --no-docstrings : 설명글을 실행 파일에 싣지 않는다
    cy -3 --embed --no-docstrings "$name.py" -o "$name.c"
    gcc -O2 -fno-ident $INC "$name.c" -o "$name" $LNK
    strip --strip-all "$name" )
  cp "$WORK/$name" "$OUT/$name"
  chmod +x "$OUT/$name" 2>/dev/null || true
  printf '  %-12s <- %s   (%s 바이트)\n' "$name" "$(basename "$src")" "$(stat -c %s "$OUT/$name")"
}

echo "실행 파일을 만든다 -> $OUT"
build "$AVO"               vfh_avoider
build "$HERE/ca_bridge.py" ca_bridge
build "$HERE/ca_viz.py"    ca_viz
rm -rf "$WORK"

echo "끝.  확인 :  USE_BIN=1 bash run_ca_nodes.sh   (소스가 있어도 실행 파일로 띄운다)"
