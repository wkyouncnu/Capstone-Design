#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# git_autopull.sh — 일을 시작하기 전에 GitHub 의 최신판을 받는다.
#                   .claude/settings.json 의 SessionStart 훅이 부른다.
#
#   bash _tools/git_autopull.sh          # 손으로 돌려도 된다
#
#   왜 있는가 (교수 지시 2026-10-23)
#     같은 저장소를 여러 PC · 여러 Claude Code 세션이 고친다. 다른 데서 올린
#     커밋을 받지 않고 시작하면, 옛 파일 위에서 일하다 푸시할 때 충돌하거나
#     남이 고친 것을 되돌린다. 그래서 세션을 열 때마다 먼저 받는다.
#
#   하는 일
#     1) git fetch
#     2) 원격이 앞서 있으면  git pull --rebase --autostash
#        - 고치던 파일은 잠깐 치웠다가(autostash) 받은 뒤 다시 얹는다 — 지우지 않는다
#        - 아직 안 올린 내 커밋은 받은 커밋 **뒤로** 옮긴다(rebase)
#     3) 충돌이 나면 rebase 를 되돌리고(abort) 손대지 않은 채 알리기만 한다
#
#   결과는 Claude Code 화면에 한 줄(systemMessage)로 남는다. 받을 것이 없으면 조용히 끝낸다.
# ---------------------------------------------------------------------------
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0

say() { printf '{"systemMessage": "%s"}\n' "$1"; echo "[autopull] $1" >&2; }

br="$(git symbolic-ref --short HEAD 2>/dev/null)" || { say "git 자동 pull 건너뜀 — 브랜치가 아님(detached)"; exit 0; }
timeout 60 git fetch -q origin "$br" 2>/dev/null || { say "git fetch 실패 — 인터넷·SSH 키 확인. 옛 판으로 작업 중일 수 있음"; exit 0; }

behind=$(git rev-list --count "HEAD..origin/$br" 2>/dev/null || echo 0)
ahead=$(git rev-list --count "origin/$br..HEAD" 2>/dev/null || echo 0)
[ "$behind" -eq 0 ] && exit 0                      # 이미 최신 — 조용히 끝

if git -c core.quotepath=off pull -q --rebase --autostash origin "$br" >/tmp/autopull.log 2>&1; then
  m="GitHub 최신판 받음 — 새 커밋 ${behind}개"
  [ "$ahead" -gt 0 ] && m="$m (아직 안 올린 내 커밋 ${ahead}개는 그 뒤로 옮김)"
  say "$m"
else
  git rebase --abort >/dev/null 2>&1
  git stash list | head -1 | grep -q autostash && git stash pop -q >/dev/null 2>&1
  say "GitHub 최신판을 받다가 충돌 — 아무것도 바꾸지 않았음. 직접: cd $ROOT && git pull --rebase"
fi
exit 0
