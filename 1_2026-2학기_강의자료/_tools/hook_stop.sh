#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# hook_stop.sh — 세션이 끝날 때 하는 뒷정리. .claude/settings.json 의 Stop 훅이 부른다.
#
#   0) 세션 표식 찍기 — 같은 체크아웃에 다른 세션이 살아 있는지 센다 (2026-11-10)
#   1) pdf_sync.sh   MD 가 PDF 보다 새로우면 PDF 재생성
#   2) git_autopull.sh  GitHub 최신판 받기 (2026-10-23)
#   3) git_autopush.sh  변경분 커밋·푸시
#
#   둘 다 실패해도 세션을 막지 않는다. 결과는 systemMessage 로 화면에 한 줄 남긴다.
# ---------------------------------------------------------------------------
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
msg=""

# ── 0) 세션 표식 ──────────────────────────────────────────────────────────
#  Stop 훅은 **턴마다** 불린다. 그래서 자기 표식을 매 턴 새로 찍으면 오래 전에
#  멈춘 세션의 표식은 저절로 묵는다 — STALE_MIN 분 안에 찍힌 것만 "살아 있다" 로 센다.
#  표식은 .git 안에 두므로 git add -A 에 걸리지 않는다.
STALE_MIN=45
PEERS=0
SID=""

if [ ! -t 0 ]; then
  SID="$(cat 2>/dev/null | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$SID" ] || SID="${CLAUDE_SESSION_ID:-}"
SID="$(printf '%s' "$SID" | tr -c '[:alnum:]._-' '_')"

GITDIR="$(git -C "$HERE" rev-parse --absolute-git-dir 2>/dev/null || true)"
if [ -n "$GITDIR" ] && [ -n "$SID" ]; then
  LIVE="$GITDIR/claude-live"
  mkdir -p "$LIVE" 2>/dev/null || true
  : > "$LIVE/$SID" 2>/dev/null || true
  PEERS=$(find "$LIVE" -maxdepth 1 -type f ! -name "$SID" -mmin "-$STALE_MIN" 2>/dev/null | wc -l | tr -d ' ')
  find "$LIVE" -maxdepth 1 -type f -mmin "+1440" -delete 2>/dev/null || true
fi

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
  push_out="$(AUTOPUSH_SCOPE=session AUTOPUSH_PEERS="$PEERS" bash "$HERE/git_autopush.sh" 2>&1)" || true
  #  보류했으면 조용히 넘기지 않는다 — 화면에 한 줄 남겨야 손으로 담을 수 있다
  if printf '%s' "$push_out" | grep -q '보류'; then
    msg="자동 커밋 보류 — 다른 세션 ${PEERS}개가 살아 있음. 자기 파일만 git add 해 커밋할 것"
  fi
fi

# 훅 출력은 JSON 한 줄. 할 말이 없으면 조용히 끝낸다
if [ -n "$msg" ]; then
  printf '{"systemMessage": "%s"}\n' "$msg"
fi
exit 0
