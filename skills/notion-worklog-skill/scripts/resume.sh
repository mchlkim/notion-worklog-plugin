#!/usr/bin/env bash
# 세션 ID로 그 세션을 이어받는 resume 명령을 만든다.
#
#   resume.sh <session-id>          명령 문자열만 출력 (복사해 쓰거나 eval)
#   resume.sh <session-id> --exec   해당 디렉토리로 이동해 그 자리에서 실행
#
# Notion 카드의 resume 속성과 같은 결과를 내되, 작업경로 속성이 비었거나
# 낡았을 때도 트랜스크립트에 기록된 실제 cwd 를 찾아 쓴다.

set -uo pipefail

id="${1:-}"
if [ -z "$id" ]; then
  echo "usage: resume.sh <session-id> [--exec]" >&2
  exit 2
fi

read_cwd() {                       # $1=트랜스크립트 경로
  grep -o '"cwd":"[^"]*"' "$1" 2>/dev/null | head -1 | sed 's/^"cwd":"//; s/"$//'
}

cmd=""; cwd=""; client=""

# ── Claude Code: ~/.claude/projects/<슬러그>/<session-id>.jsonl
f=$(ls "$HOME"/.claude/projects/*/"$id".jsonl 2>/dev/null | head -1)
if [ -n "$f" ]; then
  client="Claude Code"; cmd="claude --resume $id"; cwd=$(read_cwd "$f")
fi

# ── Codex: ~/.codex/sessions/YYYY/MM/DD/rollout-<타임스탬프>-<session-id>.jsonl
if [ -z "$cmd" ]; then
  f=$(ls "$HOME"/.codex/sessions/*/*/*/rollout-*"$id".jsonl 2>/dev/null | head -1)
  if [ -n "$f" ]; then
    client="Codex"; cmd="codex resume $id"; cwd=$(read_cwd "$f")
  fi
fi

if [ -z "$cmd" ]; then
  echo "세션 $id 을(를) 찾지 못했습니다. Claude Code·Codex 기록 모두 확인했습니다." >&2
  echo "세션 로그가 정리됐거나 다른 머신에서 만든 세션일 수 있습니다." >&2
  exit 1
fi

if [ -n "$cwd" ] && [ -d "$cwd" ]; then full="cd $cwd && $cmd"; else cwd=""; full="$cmd"; fi

if [ "${2:-}" = "--exec" ]; then
  echo "[$client] $full" >&2
  [ -n "$cwd" ] && cd "$cwd"
  exec $cmd
fi

echo "$full"
