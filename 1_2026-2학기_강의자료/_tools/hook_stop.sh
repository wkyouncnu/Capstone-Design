#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# hook_stop.sh — 세션이 끝날 때 하는 뒷정리. .claude/settings.json 의 Stop 훅이 부른다.
#
#   1) pdf_sync.sh   MD 가 PDF 보다 새로우면 PDF 재생성
#   2) git_autopull.sh  GitHub 최신판 받기 (2026-10-23)
#   3) git_autopush.sh  변경분 커밋·푸시
#
#   둘 다 실패해도 세션을 막지 않는다. 결과는 systemMessage 로 화면에 한 줄 남긴다.
# ---------------------------------------------------------------------------
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
msg=""

if [ -f "$HERE/pdf_sync.sh" ]; then
  pdf_out="$(bash "$HERE/pdf_sync.sh" 2>&1)" || true
  if printf '%s' "$pdf_out" | grep -q '실패'; then
    msg="PDF 재생성 실패 — PDF 뷰어를 닫고 'bash _tools/pdf_sync.sh' 재실행"
  elif printf '%s' "$pdf_out" | grep -q '\[OK\]'; then
    n=$(printf '%s' "$pdf_out" | grep -c '\[OK\]')
    msg="PDF ${n}건 재생성"
  fi
fi

#  올리기 전에 먼저 받는다 — 세션 도중 다른 PC·세션이 올린 커밋이 있으면 푸시가 거절되거나
#  남의 것을 되돌린다 (교수 지시 2026-10-23: "항상 끝나면 git pull")
if [ -f "$HERE/git_autopull.sh" ]; then
  bash "$HERE/git_autopull.sh" > /dev/null 2>&1 || true
fi

if [ -f "$HERE/git_autopush.sh" ]; then
  bash "$HERE/git_autopush.sh" > /dev/null 2>&1 || true
fi

# 훅 출력은 JSON 한 줄. 할 말이 없으면 조용히 끝낸다
if [ -n "$msg" ]; then
  printf '{"systemMessage": "%s"}\n' "$msg"
fi
exit 0
