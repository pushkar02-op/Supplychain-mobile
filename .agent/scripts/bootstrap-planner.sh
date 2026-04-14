#!/usr/bin/env bash
# bootstrap-planner.sh — Produce a clipboard blob for a new planner chat.
# Run this before starting a new Claude/ChatGPT planner session.
# Paste the output as the first message in the chat.
#
# Usage:
#   ./bootstrap-planner.sh               # prints to stdout
#   ./bootstrap-planner.sh | clip        # Windows clipboard (clip.exe)
#   ./bootstrap-planner.sh | pbcopy      # macOS clipboard
#   ./bootstrap-planner.sh | xclip -sel c  # Linux clipboard
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CORE_DIR=".agent/CORE"
STATE_DIR=".agent/STATE"
SESSIONS_DIR=".agent/SESSIONS"
PROMPTS_DIR=".agent/PROMPTS"

hr() { echo ""; echo "---"; echo ""; }

echo "## AGENT BOOTSTRAP v2 — PLANNER MODE"
echo ""
echo "Paste target: new Claude/ChatGPT planner chat"
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
hr

# Planner bootstrap instructions
echo "### INSTRUCTIONS"
cat "$PROMPTS_DIR/planner-bootstrap.md"
hr

# CORE files
for f in "$CORE_DIR"/0*.md; do
  echo "### CORE: $(basename "$f")"
  cat "$f"
  hr
done

# Current state
echo "### STATE: state.json"
cat "$STATE_DIR/state.json"
hr

echo "### STATE: open-threads.md"
cat "$STATE_DIR/open-threads.md"
hr

echo "### STATE: risks.md"
cat "$STATE_DIR/risks.md"
hr

# Recent sessions (last 3, newest first)
echo "### RECENT SESSIONS (last 3)"
recent=$(ls -t "$SESSIONS_DIR"/*.md 2>/dev/null | head -3 || true)
if [[ -z "$recent" ]]; then
  echo "(no sessions yet)"
else
  for f in $recent; do
    echo "#### $(basename "$f")"
    cat "$f"
    hr
  done
fi
hr

# Template reminder
echo "### PROMPT TEMPLATES"
echo "Full templates at: .agent/PROMPTS/"
echo ""
echo "CONTEXT FETCH REQUEST — emit as a single fenced code block:"
echo '```'
cat "$PROMPTS_DIR/context-fetch.md" | grep -A 20 "## Filled example" | tail -18
echo '```'
hr

echo "## END OF BOOTSTRAP PASTE"
echo "Confirm to the human: 'Design v2 loaded. Ready in Planner mode.'"
