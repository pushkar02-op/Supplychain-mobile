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

# ---------------------------------------------------------------------------
# PRE-FLIGHT VALIDATION — runs before any output is produced.
# A failure here is safe: nothing has been written to stdout yet.
# ---------------------------------------------------------------------------
required_files=(
  "$PROMPTS_DIR/planner-bootstrap.md"
  "$STATE_DIR/state.json"
  "$STATE_DIR/open-threads.md"
  "$STATE_DIR/risks.md"
)
for req in "${required_files[@]}"; do
  [[ -f "$req" ]] || { echo "ABORT: missing required file: $req" >&2; exit 1; }
  [[ -s "$req" ]] || { echo "ABORT: required file is empty: $req" >&2; exit 1; }
done

# Verify at least one CORE file exists (glob fallback = literal pattern = not a file)
core_check=( "$CORE_DIR"/0*.md )
[[ -f "${core_check[0]}" ]] || { echo "ABORT: no CORE files found in $CORE_DIR" >&2; exit 1; }
# ---------------------------------------------------------------------------

hr() { echo ""; echo "---"; echo ""; }

echo "<!-- BOOTSTRAP_START -->"
echo "## AGENT BOOTSTRAP v2 — PLANNER MODE"
echo ""
echo "Paste target: new Claude/ChatGPT planner chat"
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
hr

# Planner bootstrap instructions
echo "### INSTRUCTIONS"
cat "$PROMPTS_DIR/planner-bootstrap.md"
hr

# CORE files — sorted explicitly to guarantee 00→01→02… load order
while IFS= read -r f; do
  echo "### CORE: $(basename "$f")"
  cat "$f"
  hr
done < <(printf '%s\n' "$CORE_DIR"/0*.md | sort)

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

# Session index — gives planner navigable history when sessions > 3
if [[ -f "$SESSIONS_DIR/INDEX.md" ]]; then
  echo "### SESSIONS INDEX"
  cat "$SESSIONS_DIR/INDEX.md"
  hr
fi

# Recent sessions (last 3, newest first by filename — YYYY-MM-DD prefix makes
# reverse lexicographic sort equivalent to reverse chronological order)
echo "### RECENT SESSIONS (last 3)"
recent=$(ls "$SESSIONS_DIR"/*.md 2>/dev/null | grep -v 'INDEX\.md' | sort -r | head -3 || true)
if [[ -z "$recent" ]]; then
  echo "(no sessions yet)"
else
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    echo "#### $(basename "$f")"
    cat "$f"
    hr
  done <<< "$recent"
fi
hr

# Full context-fetch template — no grep/tail fragility
echo "### PROMPT TEMPLATES"
echo "Full templates at: .agent/PROMPTS/"
echo ""
echo "CONTEXT FETCH REQUEST — full template:"
cat "$PROMPTS_DIR/context-fetch.md"
hr

echo "## END OF BOOTSTRAP PASTE"
echo "<!-- BOOTSTRAP_END -->"
echo ""
echo "VERIFY: If both <!-- BOOTSTRAP_START --> and <!-- BOOTSTRAP_END --> are not"
echo "present in this paste, the bootstrap is incomplete. Ask the human to"
echo "re-run bootstrap-planner.sh before proceeding."
echo ""
echo "Confirm to the human: 'Design v2 loaded. Ready in Planner mode.'"
