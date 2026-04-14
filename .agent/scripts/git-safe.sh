#!/usr/bin/env bash
# git-safe.sh — Read-only git wrapper for agent context-fetch sessions.
# Agents run this during CONTEXT FETCH REQUEST steps.
# Only whitelisted git subcommands are allowed.
# No writes, no commits, no pushes, no branch operations.
set -euo pipefail

ALLOWED=(status log diff show branch rev-parse ls-files)

if [[ $# -eq 0 ]]; then
  echo "Usage: git-safe.sh <git-subcommand> [args...]"
  exit 1
fi

SUBCMD="$1"

for allowed in "${ALLOWED[@]}"; do
  if [[ "$SUBCMD" == "$allowed" ]]; then
    exec git "$@"
  fi
done

echo "git-safe: '$SUBCMD' is not an allowed read-only git command." >&2
echo "Allowed: ${ALLOWED[*]}" >&2
exit 1
