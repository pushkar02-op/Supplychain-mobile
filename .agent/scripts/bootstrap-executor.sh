#!/usr/bin/env bash
# bootstrap-executor.sh — Produce a clipboard blob for a new executor session.
# Run this before pasting a brief to Claude Code, Codex, or another executor.
# The output goes first, followed immediately by the EXECUTOR BRIEF.
#
# Usage:
#   ./bootstrap-executor.sh               # prints to stdout
#   ./bootstrap-executor.sh | clip        # Windows clipboard
#   ./bootstrap-executor.sh | pbcopy      # macOS clipboard
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PROMPTS_DIR=".agent/PROMPTS"
STATE_DIR=".agent/STATE"

hr() { echo ""; echo "---"; echo ""; }

echo "## AGENT BOOTSTRAP v2 — EXECUTOR MODE"
echo ""
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Last commit: $(git log --oneline -1)"
hr

# Executor bootstrap instructions
cat "$PROMPTS_DIR/executor-bootstrap.md"
hr

# Current state (summary)
echo "### CURRENT STATE"
cat "$STATE_DIR/state.json"
hr

echo "### OPEN THREADS"
cat "$STATE_DIR/open-threads.md"
hr

echo "## END OF BOOTSTRAP"
echo "The EXECUTOR BRIEF follows immediately below."
echo ""
echo "--- PASTE EXECUTOR BRIEF HERE ---"
