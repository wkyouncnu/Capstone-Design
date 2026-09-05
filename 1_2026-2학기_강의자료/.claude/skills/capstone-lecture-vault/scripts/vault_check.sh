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

# ── 실행 ──────────────────────────────────────────────────────────────────
echo "볼트: $ROOT"
case "$MODE" in
  --style) check_style ;;
  --links) check_links ;;
  *)       check_pdf; check_links; check_style; check_svg ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  echo "  통과 — 지적 사항 0 건"
else
  echo "  지적 사항 $FAIL 건"
fi
exit 0
