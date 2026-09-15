#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# pdf_sync.sh — MD 가 PDF 보다 새로우면 PDF 를 다시 뽑는다.
#
#   bash _tools/pdf_sync.sh            # 볼트 전체 검사 후 갱신
#   bash _tools/pdf_sync.sh --check    # 검사만 (생성하지 않음). 갱신 대상 수를 종료코드로
#
#   왜 필요한가
#     배포본은 MD + PDF 쌍이다. MD 만 고치고 PDF 를 안 뽑으면 학생이 받는 문서가
#     어긋난다. 사람이 기억하는 대신 세션이 끝날 때 훅이 이 스크립트를 부른다.
#
#   대상 — 배포·공유 폴더의 MD 중
#     (1) 짝 PDF 가 있는데 MD 가 더 새로운 것
#     (2) 주차자료·과제 폴더에서 짝 PDF 가 아예 없는 것 (README 제외)
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

stale=""
for d in $DIRS; do
  [ -d "$VAULT/$d" ] || continue
  for md in "$VAULT/$d"/*.md; do
    [ -f "$md" ] || continue
    base="$(basename "$md" .md)"
    [ "$base" = "README" ] && continue
    pdf="${md%.md}.pdf"
    if [ -f "$pdf" ]; then
      [ "$md" -nt "$pdf" ] && stale="$stale$md"$'\n'
    else
      case "$d" in
        10-주차별-강의자료|80-과제) stale="$stale$md"$'\n' ;;
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

echo "pdf_sync: MD 가 더 새로운 문서 ${n}건"
printf '%s\n' "$stale" | sed 's|^|  - |'

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
