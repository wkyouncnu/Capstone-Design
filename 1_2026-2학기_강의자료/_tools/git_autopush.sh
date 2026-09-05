#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# git_autopush.sh — 바뀐 것이 있으면 커밋하고 GitHub 로 올린다
#
#   수동 실행
#     bash _tools/git_autopush.sh
#     bash _tools/git_autopush.sh "직접 쓴 커밋 메시지"
#
#   Claude Code 의 Stop 훅으로도 호출된다 (.claude/settings.json)
#
#   설계 원칙
#     - 올리면 안 되는 것이 스테이징되면 **중단한다.** 되돌릴 수 없기 때문이다
#     - 푸시가 실패해도 exit 0 — 세션을 막지 않는다. 커밋은 이미 남아 있다
# ---------------------------------------------------------------------------
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 0
[ -d .git ] || { echo "[autopush] git 저장소가 아님: $REPO"; exit 0; }

MSG="${1:-}"
MAXMB=95                      # GitHub 파일당 한도 100 MB 보다 낮게 잡는다

# ── 푸시 ──────────────────────────────────────────────────────────────────
do_push() {
  git remote get-url origin >/dev/null 2>&1 || { echo "[autopush] origin 미설정 — 로컬 커밋만 함"; return 0; }
  local br ahead err
  br="$(git rev-parse --abbrev-ref HEAD)"
  err="$(mktemp)"

  if git rev-parse --verify -q "origin/$br" >/dev/null; then
    ahead=$(git rev-list --count "origin/$br..HEAD")
    if [ "$ahead" -eq 0 ]; then echo "[autopush] 원격과 같음 — 올릴 것 없음"; rm -f "$err"; return 0; fi
    echo "[autopush] 올릴 커밋 ${ahead}개"
  fi

  if GIT_SSH_COMMAND="ssh -o BatchMode=yes" git push -q origin "$br" 2>"$err"; then
    echo "[autopush] 푸시 완료 → origin/$br"
  else
    echo "[autopush] 푸시 실패 (커밋은 로컬에 남아 있음)"
    sed 's/^/    /' "$err" | head -4
    case "$(cat "$err")" in
      *publickey*)   echo "    → SSH 공개키가 GitHub 에 등록되지 않았다. 스킬 문서의 '처음 한 번' 절 참고" ;;
      *"not found"*|*"does not exist"*) echo "    → 원격 저장소가 없다. GitHub 에서 먼저 만들 것" ;;
      *"fetch first"*|*"non-fast-forward"*) echo "    → 원격이 앞서 있다. git pull --rebase origin $br 후 재시도" ;;
    esac
  fi
  rm -f "$err"
}

# ── 바뀐 것이 있는가 ──────────────────────────────────────────────────────
# 작업 트리가 깨끗해도 **밀린 커밋이 있으면 푸시해야 한다.**
# 여기서 exit 하면 커밋만 쌓이고 원격에 영영 올라가지 않는다.
if [ -z "$(git status --porcelain)" ]; then
  echo "[autopush] 새로 바뀐 것 없음 — 밀린 커밋만 확인한다"
  do_push
  exit 0
fi

git add -A

# ── 안전장치 1 · 개인정보가 섞였는가 ──────────────────────────────────────
BAD="$(git diff --cached --name-only | grep -E '5_학생제출물|출석부|sessionDetails|\.pem$|\.key$|^\.env$' || true)"
if [ -n "$BAD" ]; then
  echo "[autopush] 중단 — 올리면 안 되는 파일이 포함됨:"
  echo "$BAD" | sed 's/^/    /'
  echo "    .gitignore 를 확인할 것. 커밋하지 않았다."
  git reset -q
  exit 0
fi

# ── 안전장치 2 · 너무 큰 파일이 있는가 ────────────────────────────────────
BIG=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
  if [ "$sz" -gt $((MAXMB * 1024 * 1024)) ]; then
    BIG="$BIG    $((sz / 1024 / 1024)) MB  $f"$'\n'
  fi
done < <(git diff --cached --name-only)
if [ -n "$BIG" ]; then
  echo "[autopush] 중단 — ${MAXMB} MB 초과 파일이 포함됨 (GitHub 이 거부함):"
  printf '%s' "$BIG"
  echo "    .gitignore 에 추가한 뒤 다시 실행할 것. 커밋하지 않았다."
  git reset -q
  exit 0
fi

# ── 커밋 ──────────────────────────────────────────────────────────────────
if [ -z "$MSG" ]; then
  N=$(git diff --cached --name-only | wc -l | tr -d ' ')
  TOP=$(git diff --cached --name-only | awk -F/ '{print $1}' | sort -u | head -3 | tr '\n' ' ')
  MSG="자료 갱신 $(date '+%Y-%m-%d %H:%M') — ${N}개 파일 (${TOP})"
fi
git commit -q -m "$MSG" || { echo "[autopush] 커밋할 것 없음"; do_push; exit 0; }
echo "[autopush] 커밋: $(git log --oneline -1)"

do_push
exit 0
