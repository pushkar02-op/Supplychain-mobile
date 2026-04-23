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

# ---------------------------------------------------------------------------
# PRE-FLIGHT VALIDATION — runs before any output is produced.
# ---------------------------------------------------------------------------
required_files=(
  "$PROMPTS_DIR/executor-bootstrap.md"
  "$STATE_DIR/risks.md"
)
for req in "${required_files[@]}"; do
  [[ -f "$req" ]] || { echo "ABORT: missing required file: $req" >&2; exit 1; }
  [[ -s "$req" ]] || { echo "ABORT: required file is empty: $req" >&2; exit 1; }
done
# ---------------------------------------------------------------------------

hr() { echo ""; echo "---"; echo ""; }

echo "<!-- BOOTSTRAP_START -->"
echo "## AGENT BOOTSTRAP v2 — EXECUTOR MODE"
echo ""
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Last commit: $(git log --oneline -1)"
hr

# Executor bootstrap instructions
cat "$PROMPTS_DIR/executor-bootstrap.md"
hr

# Active risks — executor must be aware before touching any subsystem
echo "### ACTIVE RISKS"
cat "$STATE_DIR/risks.md"
hr

echo "## END OF BOOTSTRAP"
echo "<!-- BOOTSTRAP_END -->"
echo ""
echo "VERIFY: If both <!-- BOOTSTRAP_START --> and <!-- BOOTSTRAP_END --> are not"
echo "present in this paste, the bootstrap is incomplete. Ask the human to"
echo "re-run bootstrap-executor.sh before proceeding."
echo ""
echo "The EXECUTOR BRIEF follows immediately below."
echo ""
echo "--- PASTE EXECUTOR BRIEF HERE ---"
