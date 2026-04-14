#!/usr/bin/env bash
# context-fetch.sh — Read-only repo snapshot for planner context requests.
# Run this when the planner emits a CONTEXT FETCH REQUEST.
# Paste the output back to the planner chat.
#
# Usage:
#   ./context-fetch.sh                  # runs the default snapshot
#   ./context-fetch.sh <command> [...]  # runs a specific read-only command
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

SAFE_CMDS=(cat grep find ls head tail wc git)

is_safe_git() {
  local subcmd="${1:-}"
  local allowed=(status log diff show branch rev-parse ls-files)
  for a in "${allowed[@]}"; do
    [[ "$subcmd" == "$a" ]] && return 0
  done
  return 1
}

if [[ $# -gt 0 ]]; then
  # Passthrough mode: run the requested read-only command
  CMD="$1"
  # Basic safety: only allow known read-only tools
  case "$CMD" in
    cat|grep|find|ls|head|tail|wc) exec "$@" ;;
    git)
      shift
      SUBCMD="${1:-}"
      if is_safe_git "$SUBCMD"; then
        exec git "$@"
      else
        echo "context-fetch: git '$SUBCMD' is not allowed in read-only mode." >&2
        exit 1
      fi
      ;;
    *)
      echo "context-fetch: '$CMD' is not an allowed read-only command." >&2
      exit 1
      ;;
  esac
fi

# Default snapshot (no args)
echo "=== CONTEXT FETCH SNAPSHOT ==="
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
echo ""

echo "--- git status --short ---"
git status --short

echo ""
echo "--- git branch (current) ---"
git rev-parse --abbrev-ref HEAD

echo ""
echo "--- git log --oneline -10 ---"
git log --oneline -10

echo ""
echo "--- .agent/STATE/state.json ---"
cat .agent/STATE/state.json

echo ""
echo "--- .agent/STATE/open-threads.md (first 40 lines) ---"
head -40 .agent/STATE/open-threads.md 2>/dev/null || echo "(not found)"

echo ""
echo "=== END SNAPSHOT ==="
