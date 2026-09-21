#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# vault_check.sh — 캡스톤디자인 볼트 점검
#
#   사용법 (Git Bash, 볼트 루트에서)
#     bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh
#     bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh --style
#     bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh --links
#
#   합격선은 전 항목 0 건.
#   폴더명의 [2026-2] / [2025] 대괄호 때문에 find -path 패턴을 쓰지 않는다.
#   CLAUDE.md 는 규칙을 설명하려고 금지 표현을 인용하므로 검사 대상에서 뺀다.
# ---------------------------------------------------------------------------
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT" || exit 1
[ -f CLAUDE.md ] || { echo "오류: 볼트 루트를 찾을 수 없습니다 ($ROOT)"; exit 1; }

MODE="${1:-all}"
FAIL=0
note()  { printf '  %-40s %s\n' "$1" "$2"; }
head2() { printf '\n%s\n' "$1"; }

# 검사 대상 MD — 코드 사본·템플릿·스킬 문서·규칙 원본은 제외
mds() {
  find . -name '*.md' -type f \
    | grep -v '/\.claude/' \
    | grep -v '/_templates/' \
    | grep -v 'ROS2_VRX_Gazebo_Simulink' \
    | grep -v '/slprj/' \
    | grep -v '^\./CLAUDE\.md$' \
    | sort
}

# 규칙을 인용한 예시가 걸리지 않도록 코드블록·인라인 코드를 지운 사본으로 본다
strip_code() { awk '/^```/{f=!f; next} !f' "$1" | sed 's/`[^`]*`//g'; }

# ── 1. MD ↔ PDF 쌍 ────────────────────────────────────────────────────────
check_pdf() {
  head2 "1. MD - PDF 쌍"
  local miss=0 stale=0 f pdf
  while IFS= read -r f; do
    case "$f" in
      ./10-주차별-강의자료/*|./80-과제/*|./00-운영/*|./30-환경/*) ;;
      *) continue ;;
    esac
    case "$(basename "$f")" in README.md) continue ;; esac
    pdf="${f%.md}.pdf"
    if [ ! -f "$pdf" ]; then
      echo "     [PDF 없음] $f"; miss=$((miss+1))
    elif [ "$f" -nt "$pdf" ]; then
      echo "     [PDF 가 오래됨] $f"; stale=$((stale+1))
    fi
  done < <(mds)
  note "PDF 누락" "$miss"
  note "PDF 가 MD 보다 오래됨" "$stale"
  [ $stale -gt 0 ] && echo "     -> bash _tools/md2pdf.sh <파일.md>"
  FAIL=$((FAIL+miss+stale))
  return 0
}

# ── 2. 링크와 그림 ────────────────────────────────────────────────────────
check_links() {
  head2 "2. wikilink"
  local bad=0 f raw name
  while IFS= read -r f; do
    while IFS= read -r raw; do
      name="${raw%%|*}"; name="${name%%#*}"
      [ -z "$name" ] && continue
      if ! find . -name "$name.md" -type f 2>/dev/null | grep -q .; then
        echo "     [깨짐] $f  ->  [[$name]]"; bad=$((bad+1))
      fi
    done < <(strip_code "$f" | sed 's/!\[\[/@@IMG@@/g' | grep -o '\[\[[^]]*\]\]' \
             | sed 's/^\[\[//; s/\]\]$//' | sort -u)
  done < <(mds)
  note "깨진 wikilink" "$bad"
  FAIL=$((FAIL+bad))

  head2 "3. 그림 참조"
  local img=0 d p
  while IFS= read -r f; do
    d="$(dirname "$f")"
    while IFS= read -r p; do
      case "$p" in http*|data:*) continue ;; esac
      [ -f "$d/$p" ] || { echo "     [없음] $f  ->  $p"; img=$((img+1)); }
    done < <(grep -o '](\([^)]*\.\(svg\|png\|jpg\|jpeg\|gif\)\))' "$f" \
             | sed 's/^](//; s/)$//' | sort -u)
  done < <(mds)
  note "없는 그림" "$img"
  FAIL=$((FAIL+img))

  head2 "4. Obsidian 전용 임베드"
  local emb=0
  while IFS= read -r f; do
    if strip_code "$f" | grep -q '!\[\['; then echo "     $f"; emb=$((emb+1)); fi
  done < <(mds)
  note "Obsidian 임베드를 쓴 문서" "$emb"
  FAIL=$((FAIL+emb))
  return 0
}

# ── 3. 문체 ───────────────────────────────────────────────────────────────
check_style() {
  head2 "5. 금지 표현"
  local words=(여러분 우리 오늘 함정 지뢰 드디어 "담당 노트북" "★")
  local w n total=0 f hits
  for w in "${words[@]}"; do
    n=0
    while IFS= read -r f; do
      hits=$(strip_code "$f" | grep -o -- "$w" | wc -l)
      if [ "$hits" -gt 0 ]; then n=$((n+hits)); echo "     $f  ($hits)"; fi
    done < <(mds)
    printf '  %-40s %s\n' "$w" "$n"
    total=$((total+n))
  done
  note "합계" "$total"
  FAIL=$((FAIL+total))

  head2 "6. 콜아웃 종류"
  local badc=0
  while IFS= read -r f; do
    hits=$(grep -oh '> \[![a-z]*\]' "$f" 2>/dev/null \
           | grep -vcE '\[!(note|tip|important|warning|caution|info)\]')
    if [ "$hits" -gt 0 ]; then echo "     $f  ($hits)"; badc=$((badc+hits)); fi
  done < <(mds)
  note "미지원 콜아웃" "$badc"
  FAIL=$((FAIL+badc))
  return 0
}

# ── 4. SVG · 잔여물 ───────────────────────────────────────────────────────
check_svg() {
  head2 "7. SVG 흰 배경"
  local bad=0 s
  for s in assets/*.svg; do
    [ -f "$s" ] || continue
    grep -qiE 'fill="#(ffffff|fff)"' "$s" || { echo "     [배경 없음] $s"; bad=$((bad+1)); }
  done
  note "흰 배경 사각형이 없는 SVG" "$bad"
  FAIL=$((FAIL+bad))

  head2 "8. 남은 백업 파일"
  local n
  n=$( { find . -name '*.bak'; find . -name '*.orig'; } 2>/dev/null \
       | grep -v 'ROS2_VRX_Gazebo_Simulink' | wc -l )
  note "*.bak / *.orig" "$n"
  FAIL=$((FAIL+n))
  return 0
}

# ── 5. 그림 소스 ──────────────────────────────────────────────────────────
check_fig() {
  head2 "9. TikZ 그림 — 빌드 누락"
  local n=0 t b
  for t in assets/src/*.tex; do
    [ -f "$t" ] || continue
    case "$(basename "$t")" in capstone-style.tex) continue ;; esac
    b="assets/$(basename "${t%.tex}").svg"
    if [ ! -f "$b" ]; then
      echo "     [SVG 없음] $t"; n=$((n+1))
    elif [ "$t" -nt "$b" ]; then
      echo "     [소스가 더 최신] $t"; n=$((n+1))
    fi
  done
  note "다시 빌드해야 하는 그림" "$n"
  [ $n -gt 0 ] && echo "     -> bash _tools/tikz2svg.sh <소스.tex> <출력.svg>"
  FAIL=$((FAIL+n))

  head2 "10. 그림 안의 금지 표현"
  # 수작업 SVG 와 TikZ 소스의 글자를 검사한다. 본문만 보면 그림에 남은 것을 놓친다.
  local words=(여러분 우리 오늘 함정 지뢰 드디어 "★")
  local bad=0 f w hits
  for f in assets/*.svg assets/src/*.tex; do
    [ -f "$f" ] || continue
    grep -q dvisvgm "$f" 2>/dev/null && continue   # 빌드 산출물은 글자가 path 라 검사 불가
    for w in "${words[@]}"; do
      hits=$(grep -o -- "$w" "$f" 2>/dev/null | wc -l)
      if [ "$hits" -gt 0 ]; then echo "     $f  :  $w ($hits)"; bad=$((bad+hits)); fi
    done
  done
  note "그림 소스의 금지 표현" "$bad"
  FAIL=$((FAIL+bad))

  head2 "11. MD 수식 구문"
  local m=0
  while IFS= read -r f; do
    # $$ 블록이 짝을 이루는지. 홀수면 수식이 본문으로 새어 나온다.
    local nn
    nn=$(grep -o '\$\$' "$f" | wc -l)
    if [ $((nn % 2)) -ne 0 ]; then echo "     [\$\$ 짝 안 맞음] $f  ($nn 개)"; m=$((m+1)); fi
  done < <(mds)
  note "수식 구분자 불일치" "$m"
  FAIL=$((FAIL+m))
  return 0
}

check_struct() {
  head2 "12. 주차 문서 구조"
  # "# 마무리" 뒤에 실습 절(## 2-3. / ## D. …)이 오면 그 절이 마무리의 일부로 렌더된다.
  # 2026-09-18 4주차에서 2-6 · 2-7 절이 그렇게 되어 있었다.
  local bad=0 f
  for f in 10-주차별-강의자료/W*.md; do
    [ -f "$f" ] || continue
    local hit
    hit=$(awk '/^# 마무리$/{m=1; next} m && /^## ([0-9]+-[0-9]+\.|[A-Z]\. )/{print FNR": "$0}' "$f")
    if [ -n "$hit" ]; then
      printf '     %s\n' "$f"; printf '%s\n' "$hit" | sed 's/^/        /'
      bad=$((bad + $(printf '%s\n' "$hit" | grep -c .)))
    fi
  done
  note "마무리 뒤에 놓인 실습 절" "$bad"
  FAIL=$((FAIL+bad))

  head2 "16. 첫 페이지의 강의자료 저장소 블록"
  # 학생이 어느 문서를 열어도 첫 페이지에서 저장소 주소와 git pull 절차를 보아야 한다.
  # 원본은 _templates/강의자료저장소블록.md — 문서마다 고쳐 쓰지 않는다.
  local miss=0 g
  for g in 10-주차별-강의자료/W*.md 00-운영/강의계획서.md 00-운영/평가와-팀운영.md \
           00-운영/AI에이전트-활용-정책.md; do
    [ -f "$g" ] || continue
    if ! grep -q '강의자료 저장소 — 처음 한 번만' "$g"; then
      echo "     [블록 없음] $g"; miss=$((miss+1))
    elif [ "$(grep -n 'github.com/wkyouncnu/Capstone-Design>' "$g" | head -1 | cut -d: -f1)" -gt 60 ]; then
      echo "     [첫 페이지 아님] $g"; miss=$((miss+1))
    fi
  done
  note "저장소 블록 누락" "$miss"
  [ $miss -gt 0 ] && echo "     -> _templates/강의자료저장소블록.md 를 참조 강의 블록 뒤에 넣는다"
  FAIL=$((FAIL+miss))
}

check_refs() {
  # 다른 주차를 가리키는 약속 — "8주차에서 다룬다" 같은 문장.
  # 강의계획서가 바뀌면 조용히 틀린다. 2026-09-18 에 14곳이 틀린 주차를 가리키고 있었다.
  # 뜻까지 기계로 맞출 수는 없으므로, 그 주차의 실제 제목을 옆에 붙여 사람이 본다.
  local verbose=${1:-0}
  head2 "13. 다른 주차를 가리키는 약속 (눈으로 확인 — 지적 수에 넣지 않는다)"
  local plan=00-운영/강의계획서.md
  [ -f "$plan" ] || { note "강의계획서 없음" "-"; return 0; }
  local n=0 f line wk title
  while IFS= read -r line; do
    f=${line%%:*}; rest=${line#*:}; ln=${rest%%:*}; txt=${rest#*:}
    wk=$(printf '%s' "$txt" | grep -oE '[0-9]{1,2}주차' | head -1 | tr -dc '0-9')
    [ -z "$wk" ] && continue
    title=$(grep -m1 -E "^#### ${wk}주차 · " "$plan" | sed -E "s/^#### ${wk}주차 · //")
    n=$((n+1))
    if [ "$verbose" -eq 1 ]; then
      printf '     %-14s %5s  -> %2s주차 [%s]\n' "$(basename "$f" | cut -c1-12)" "$ln" "$wk" "${title:-계획서에 없음}"
      printf '            %s\n' "$(printf '%s' "$txt" | sed 's/^ *//' | cut -c1-110)"
    fi
  done < <(grep -nHE '[0-9]{1,2}주차[^|]{0,40}(다룬다|유도한다|배운다|계산한다|이어진다|다룸|한다\.)' 10-주차별-강의자료/W*.md)
  note "다른 주차를 가리키는 문장" "$n"
  [ "$verbose" -eq 0 ] && echo "     (목록과 각 주차의 실제 제목은 --refs 로 본다)"
  return 0
}

check_tilde() {
  head2 "14. 취소선이 되는 물결표"
  # 본문의 "−90°~+90°" 같은 범위 표시 ~ 가 한 문단에 둘이면 marked · GitHub 가 그 사이를
  # 취소선으로 그린다 (GFM ~text~). 2026-09-18 에 231곳이었다. 고치는 법:
  #   perl _tools/escape_tilde.pl <파일...>      (코드 · 수식 안은 건드리지 않는다)
  local n
  n=$(perl _tools/escape_tilde.pl --check 10-주차별-강의자료/*.md 80-과제/*.md 00-운영/*.md \
        30-환경/*.md 20-지식/*.md README.md 2>/dev/null | awk '/^합계/{print $2}')
  n=${n:-0}
  [ "$n" -gt 0 ] && perl _tools/escape_tilde.pl --check 10-주차별-강의자료/*.md 80-과제/*.md \
        00-운영/*.md 30-환경/*.md 20-지식/*.md README.md 2>/dev/null | grep -v "^합계" | sed 's/^/    /'
  note "이스케이프 안 된 범위 물결표 · 코드 안 \\~ · 홀수 펜스" "$n"
  FAIL=$((FAIL+n))
}

check_ctrl() {
  head2 "15. 문서에 섞인 제어문자"
  # 셸 치환(sed · perl)으로 LaTeX 를 고치면 \t \r \b \f 가 제어문자로 바뀐다.
  # 2026-09-18 — $\times$ 가 $<TAB>imes$ 로, \rvert 의 \r 이 줄바꿈으로 깨졌다.
  # TAB 은 캡처한 출력 코드블록 안에 원래 있을 수 있어 세지 않는다.
  local n=0 f c
  for f in 10-주차별-강의자료/*.md 80-과제/*.md 00-운영/*.md 20-지식/*.md 30-환경/*.md README.md; do
    [ -f "$f" ] || continue
    c=$(grep -cP '[\x00-\x08\x0b\x0c\x0e-\x1f]' "$f")
    if [ "$c" -gt 0 ]; then echo "    $f  $c 줄"; n=$((n+c)); fi
  done
  note "제어문자가 든 줄" "$n"
  FAIL=$((FAIL+n))
}

# ── 실행 ──────────────────────────────────────────────────────────────────
echo "볼트: $ROOT"
case "$MODE" in
  --style) check_style ;;
  --links) check_links ;;
  --fig)   check_fig ;;
  --refs)  check_refs 1 ;;
  --struct) check_struct ;;
  *)       check_pdf; check_links; check_style; check_svg; check_fig; check_struct; check_tilde; check_ctrl; check_refs 0 ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  echo "  통과 — 지적 사항 0 건"
else
  echo "  지적 사항 $FAIL 건"
fi
exit 0
