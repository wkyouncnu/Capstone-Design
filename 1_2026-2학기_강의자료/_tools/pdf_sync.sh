#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# pdf_sync.sh — PDF 가 원본보다 오래되었으면 다시 뽑는다.
#
#   bash _tools/pdf_sync.sh            # 볼트 전체 검사 후 갱신
#   bash _tools/pdf_sync.sh --check    # 검사만 (생성하지 않음). 갱신 대상 수를 종료코드로
#
#   왜 필요한가
#     배포본은 MD + PDF 쌍이다. MD 만 고치고 PDF 를 안 뽑으면 학생이 받는 문서가
#     어긋난다. 사람이 기억하는 대신 세션이 끝날 때 훅이 이 스크립트를 부른다.
#
#   대상 — 배포·공유 폴더의 MD 중
#     (1) 짝 PDF 가 없는 것 (주차자료·과제 폴더. README 제외)
#     (2) MD 가 PDF 보다 새로운 것
#     (3) MD 가 싣고 있는 그림 중 하나라도 PDF 보다 새로운 것
#     (4) 조판 도구(템플릿·md2pdf·marked·MathJax)가 PDF 보다 새로운 것
#
#   (3) 과 (4) 를 왜 보는가
#     MD 만 보면 조용히 어긋난다. Simulink 도면을 다시 뽑거나 템플릿의 CSS 를
#     고치면 MD 는 그대로다 — 검사는 "갱신할 것 없음" 이라 하고 PDF 는 옛 그림을
#     품은 채 남는다. 2026-09-17 에 두 번 겪었다 (그림 높이 제한, 블록 색칠).
#     그때는 전부 강제로 다시 뽑아야 했다. 이제 스크립트가 알아서 찾는다.
#
#   PDF 뷰어가 파일을 열고 있으면 덮어쓸 수 없다. 그 경우 실패를 그대로 보고한다.
# ---------------------------------------------------------------------------
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$HERE/.." && pwd)"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# PDF 를 함께 배포하는 폴더만 본다. 20-지식·40-자산은 MD 만 쓴다
DIRS="10-주차별-강의자료 80-과제 00-운영 30-환경"

# 조판 결과를 바꾸는 도구들. 이것이 바뀌면 모든 PDF 가 옛것이 된다
TOOLS="pdf-template.html md2pdf.sh marked.min.js mathjax-tex-svg.js"

#  왜 PDF 가 오래되었는가. 이유를 한 줄로 돌려준다. 최신이면 빈 문자열
why_stale() {
  local md="$1" pdf="$2" t f p dir

  [ "$md" -nt "$pdf" ] && { echo "MD"; return; }

  for t in $TOOLS; do
    f="$HERE/$t"
    [ -f "$f" ] && [ "$f" -nt "$pdf" ] && { echo "조판도구 $t"; return; }
  done

  #  MD 가 싣고 있는 그림. 표준 마크다운 ![](경로) 와 <img src="경로"> 둘 다 본다
  dir="$(dirname "$md")"
  for p in $(sed -n 's/.*!\[[^]]*\](\([^) ]*\).*/\1/p; s/.*<img[^>]*src="\([^"]*\)".*/\1/p' "$md" \
             | sed 's/[#?].*$//' | sort -u); do
    case "$p" in http*|data:*|'') continue ;; esac
    f="$dir/$p"
    [ -f "$f" ] && [ "$f" -nt "$pdf" ] && { echo "그림 $(basename "$p")"; return; }
  done

  echo ""
}

stale=""; reasons=""
for d in $DIRS; do
  [ -d "$VAULT/$d" ] || continue
  for md in "$VAULT/$d"/*.md; do
    [ -f "$md" ] || continue
    base="$(basename "$md" .md)"
    [ "$base" = "README" ] && continue
    pdf="${md%.md}.pdf"
    if [ -f "$pdf" ]; then
      r="$(why_stale "$md" "$pdf")"
      [ -n "$r" ] && { stale="$stale$md"$'\n'; reasons="$reasons$base｜$r"$'\n'; }
    else
      case "$d" in
        10-주차별-강의자료|80-과제)
          stale="$stale$md"$'\n'; reasons="$reasons$base｜PDF 없음"$'\n' ;;
      esac
    fi
  done
done

stale="$(printf '%s' "$stale" | sed '/^$/d')"
n=$(printf '%s' "$stale" | grep -c . || true)

if [ "$n" -eq 0 ]; then
  echo "pdf_sync: 갱신할 PDF 없음"
  exit 0
fi

echo "pdf_sync: 다시 뽑을 문서 ${n}건"
printf '%s' "$reasons" | sed '/^$/d' | sed 's|^|  - |'

if [ "$CHECK_ONLY" -eq 1 ]; then
  exit "$n"
fi

# md2pdf.sh 는 여러 파일을 한 번에 받는다. 결과 요약만 남긴다
out="$(cd "$VAULT" && printf '%s\n' "$stale" | xargs -d '\n' bash "$HERE/md2pdf.sh" 2>&1)"
printf '%s\n' "$out" | grep -E '\[OK\]|\[실패\]|완료:' || printf '%s\n' "$out" | tail -5

if printf '%s' "$out" | grep -q '\[실패\]'; then
  echo "pdf_sync: 실패한 PDF 가 있다 — PDF 뷰어를 닫고 다시 실행할 것"
  exit 1
fi
exit 0
