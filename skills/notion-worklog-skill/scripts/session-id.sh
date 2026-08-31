#!/usr/bin/env bash
# 현재 에이전트 세션 ID를 표준출력으로 낸다.
#
# 성공: 세션 ID 출력, 종료코드 0
# 실패: 아무것도 출력하지 않고 종료코드 1  (이때는 세션ID 속성을 비워 둔다)
#
# 우선순위
#   1. 클라이언트가 주는 환경변수      — 가장 정확
#   2. 실행 중인 트랜스크립트 파일 역산 — Codex 등 환경변수가 없는 경우
#
# 파일 역산에 "가장 최근 수정된 파일"만 쓰면 다른 클라이언트가 동시에 돌 때
# 남의 세션 ID를 집는다. 그래서 환경변수 판별을 먼저 하고, 파일 역산은 해당
# 클라이언트의 디렉토리 안에서만 한다.

set -uo pipefail

MAX_AGE_MIN="${WORKLOG_SESSION_MAX_AGE_MIN:-60}"

# ── 1) 환경변수 ────────────────────────────────────────────────
[ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && { echo "$CLAUDE_CODE_SESSION_ID"; exit 0; }
for v in CODEX_SESSION_ID CODEX_THREAD_ID AGENT_SESSION_ID; do
  val=$(printenv "$v" 2>/dev/null) || continue
  [ -n "$val" ] && { echo "$val"; exit 0; }
done

# ── 2) 트랜스크립트 역산 ───────────────────────────────────────
UUID_RE='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
newest=""; newest_mtime=0
consider() {
  [ -f "$1" ] || return
  local m; m=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null) || return
  [ "$m" -gt "$newest_mtime" ] && { newest_mtime=$m; newest=$1; }
}

if [ "${CLAUDECODE:-}" = "1" ]; then
  # Claude Code: ~/.claude/projects/<cwd 슬러그>/<session-uuid>.jsonl
  slug=$(pwd | sed 's#[/.]#-#g')
  for f in "$HOME/.claude/projects/$slug"/*.jsonl; do consider "$f"; done
else
  # Codex: ~/.codex/sessions/YYYY/MM/DD/rollout-<타임스탬프>-<uuid>.jsonl
  for f in "$HOME"/.codex/sessions/*/*/*/rollout-*.jsonl; do consider "$f"; done
fi

[ -n "$newest" ] || exit 1

# 현재 세션의 트랜스크립트는 지금도 쓰이는 중이다. 오래된 파일이면 다른 세션이므로
# 틀린 ID를 넣느니 비워 두는 편이 낫다.
[ $(( ( $(date +%s) - newest_mtime ) / 60 )) -gt "$MAX_AGE_MIN" ] && exit 1

basename "$newest" .jsonl | grep -oE "${UUID_RE}\$" || exit 1
