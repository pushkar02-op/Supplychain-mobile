#!/usr/bin/env bash
# close-session.sh — Validate SESSION CLOSE, write session file, update state,
# update CHANGELOG, commit, and push the feature branch.
#
# Run this AFTER the planner has issued REVIEW VERDICT: APPROVED.
# Never run on develop or main.
#
# Usage:
#   ./close-session.sh                   # reads SESSION CLOSE from stdin
#   ./close-session.sh session-close.txt # reads from file
#
# What this script does (see DESIGN_LOCKED.md Part H for full spec):
#   1. Read SESSION CLOSE block from stdin or file
#   2. Parse required fields
#   3. Refuse if on develop/main
#   4. Refuse if working tree is clean (nothing to commit)
#   5. Re-run validation (trust but verify)
#   6. Write session file to .agent/SESSIONS/
#   7. Apply STATE_DELTA to .agent/STATE/state.json
#   8. Update CHANGELOG.md [Unreleased] section
#   9. Update .agent/SESSIONS/INDEX.md
#  10. Stage whitelisted paths only
#  11. Commit with generated message
#  12. Push feature branch
#  13. Print PR hint
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

SCRIPTS_DIR="$REPO_ROOT/.agent/scripts"
SESSIONS_DIR="$REPO_ROOT/.agent/SESSIONS"
STATE_FILE="$REPO_ROOT/.agent/STATE/state.json"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

PROTECTED_BRANCHES=("develop" "main" "master")

# ── Helpers ──────────────────────────────────────────────────────────────────

die() { echo "REFUSED: $*" >&2; exit 1; }
info() { echo "  $*"; }

current_branch() { git rev-parse --abbrev-ref HEAD; }

ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
  python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))'
}

session_slug() {
  local branch="$1"
  local date_part
  date_part=$(date -u +"%Y-%m-%d-%H%M" 2>/dev/null || python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%d-%H%M"))')
  # Derive slug from branch name (strip leading type prefix)
  local slug
  slug=$(echo "$branch" | sed 's|.*/||' | tr '/' '-')
  echo "${date_part}-${slug}"
}

# ── Read SESSION CLOSE ────────────────────────────────────────────────────────

if [[ $# -gt 0 && -f "$1" ]]; then
  SESSION_CLOSE=$(cat "$1")
else
  echo "Paste SESSION CLOSE block below, then press Ctrl-D:"
  SESSION_CLOSE=$(cat)
fi

if [[ -z "$SESSION_CLOSE" ]]; then
  die "Empty SESSION CLOSE input."
fi

# ── Parse required fields ─────────────────────────────────────────────────────

extract_field() {
  local field="$1"
  echo "$SESSION_CLOSE" | grep -m1 "^${field}:" | sed "s/^${field}:[[:space:]]*//" | tr -d '\r'
}

PHASE=$(extract_field "PHASE")
BRANCH_FIELD=$(extract_field "BRANCH")
VALIDATION=$(extract_field "VALIDATION_STATUS")

[[ -z "$PHASE" ]]      && die "SESSION CLOSE missing PHASE field."
[[ -z "$BRANCH_FIELD" ]] && die "SESSION CLOSE missing BRANCH field."
[[ -z "$VALIDATION" ]] && die "SESSION CLOSE missing VALIDATION_STATUS field."

info "PHASE:             $PHASE"
info "BRANCH:            $BRANCH_FIELD"
info "VALIDATION_STATUS: $VALIDATION"

# ── Safety checks ─────────────────────────────────────────────────────────────

CURRENT=$(current_branch)
for protected in "${PROTECTED_BRANCHES[@]}"; do
  [[ "$CURRENT" == "$protected" ]] && die "On protected branch '$protected'. Check out a feature branch first."
done

if [[ "$CURRENT" != "$BRANCH_FIELD" ]]; then
  echo "WARNING: Current branch '$CURRENT' does not match SESSION CLOSE BRANCH '$BRANCH_FIELD'."
  read -r -p "Continue anyway? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted by user."
fi

git diff --quiet HEAD 2>/dev/null || true
if git diff --cached --quiet && git diff --quiet; then
  die "Working tree is clean — nothing to commit."
fi

# ── Validation gate ───────────────────────────────────────────────────────────

if [[ "$VALIDATION" == "FAIL" ]]; then
  die "SESSION CLOSE reports VALIDATION_STATUS: FAIL. Fix validation before closing."
fi

echo ""
echo "Re-running validation (trust but verify)..."

# Backend tests
if command -v pytest &>/dev/null; then
  pytest_changed=$(git diff --cached --name-only | grep "^backend/" | grep "\.py$" | head -1 || true)
  if [[ -n "$pytest_changed" ]]; then
    echo "Running: pytest backend/tests/ -x --tb=short -q"
    pytest backend/tests/ -x --tb=short -q || die "pytest failed. Fix before closing."
  else
    info "No Python files staged — skipping pytest."
  fi
fi

# Flutter analyze
flutter_changed=$(git diff --cached --name-only | grep "^mobile/.*\.dart$" | head -1 || true)
if [[ -n "$flutter_changed" ]]; then
  if command -v flutter &>/dev/null; then
    echo "Running: flutter analyze"
    (cd mobile && flutter analyze) || die "flutter analyze failed. Fix before closing."
  else
    echo "WARNING: flutter not found — skipping analyze."
  fi
fi

echo "Validation re-run complete."
echo ""

# ── Write session file ────────────────────────────────────────────────────────

SLUG=$(session_slug "$CURRENT")
SESSION_FILE="$SESSIONS_DIR/${SLUG}.md"

{
  echo "# Session: $SLUG"
  echo ""
  echo "**Branch:** $CURRENT"
  echo "**Closed:** $(ts)"
  echo ""
  echo '```'
  echo "$SESSION_CLOSE"
  echo '```'
} > "$SESSION_FILE"

info "Session file written: .agent/SESSIONS/${SLUG}.md"

# ── Apply STATE_DELTA ─────────────────────────────────────────────────────────

DELTA_RAW=$(echo "$SESSION_CLOSE" | awk '/^STATE_DELTA:/{found=1; next} found && /^[A-Z_]+:/{exit} found{print}')

if [[ -n "$DELTA_RAW" ]]; then
  # Convert STATE_DELTA section to JSON and apply via update-state.py.
  # Handles two-level nesting: top-level scalar/list fields and one level of
  # nested dicts (e.g. subsystems.dispatch = { ... }).
  DELTA_JSON=$(python3 -c "
import re, json

raw = '''$DELTA_RAW'''
result = {}
current_parent = None  # key of the active nested block
base_indent = None     # indentation of top-level keys (set from first match)

for line in raw.splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        continue
    m = re.match(r'^(\w+):\s*(.*)', stripped)
    if not m:
        continue
    key, val = m.group(1), m.group(2).strip().strip('\"')
    indent = len(line) - len(line.lstrip(' '))

    if base_indent is None:
        base_indent = indent  # first key sets the baseline

    if indent == base_indent:
        # Top-level key — resets any active nested block
        current_parent = None
        if val == '':
            # No value: this key heads a nested block
            current_parent = key
            result[key] = {}
        else:
            try:
                result[key] = json.loads(val) if val.startswith('[') or val.startswith('{') else val
            except json.JSONDecodeError:
                result[key] = val
    elif indent > base_indent and current_parent is not None:
        # Indented line inside a nested block
        if not isinstance(result.get(current_parent), dict):
            result[current_parent] = {}
        try:
            result[current_parent][key] = json.loads(val) if val.startswith('{') or val.startswith('[') else val.strip('\"')
        except json.JSONDecodeError:
            result[current_parent][key] = val.strip('\"')

print(json.dumps(result))
" 2>/dev/null || echo '{}')

  if [[ "$DELTA_JSON" != "{}" ]]; then
    python3 "$SCRIPTS_DIR/update-state.py" --delta "$DELTA_JSON" && \
      info "state.json updated." || \
      echo "WARNING: state delta apply failed — check manually."
  fi
fi

# ── Update SESSIONS/INDEX.md ──────────────────────────────────────────────────

INDEX="$SESSIONS_DIR/INDEX.md"
if [[ -f "$INDEX" ]]; then
  # Prepend new entry after header
  ENTRY="- [${SLUG}](${SLUG}.md) — ${PHASE} | $(ts)"
  python3 - <<PYEOF
import re
with open('$INDEX', 'r') as f:
    content = f.read()

entry = '$ENTRY'
# Insert after first blank line following a heading
lines = content.splitlines(keepends=True)
insert_at = 1
for i, line in enumerate(lines):
    if i > 0 and line.strip() == '' and i > 1:
        insert_at = i + 1
        break
lines.insert(insert_at, entry + '\n')

with open('$INDEX', 'w') as f:
    f.writelines(lines)
PYEOF
  info "SESSIONS/INDEX.md updated."
fi

# ── Update CHANGELOG.md ───────────────────────────────────────────────────────

if [[ -f "$CHANGELOG" ]]; then
  ENTRY="- $PHASE (session: $SLUG, branch: $CURRENT)"
  python3 - <<PYEOF
with open('$CHANGELOG', 'r') as f:
    content = f.read()

entry = '- $PHASE (session: $SLUG, branch: $CURRENT)\n'
marker = '## [Unreleased]'
if marker in content:
    content = content.replace(marker + '\n', marker + '\n' + entry, 1)
else:
    content = marker + '\n' + entry + '\n\n' + content

with open('$CHANGELOG', 'w') as f:
    f.write(content)
PYEOF
  info "CHANGELOG.md updated."
fi

# ── Stage whitelisted paths ───────────────────────────────────────────────────

WHITELIST=(
  ".agent/"
  "docs/"
  "CHANGELOG.md"
  "README.md"
  "backend/"
  "mobile/"
)

for path in "${WHITELIST[@]}"; do
  git add "$path" 2>/dev/null || true
done

if git diff --cached --quiet; then
  die "Nothing staged after whitelisting. Check that your changes are in whitelisted paths."
fi

# ── Documentation enforcement ─────────────────────────────────────────────────

staged_files=$(git diff --cached --name-only)
code_changed=$(echo "$staged_files" | grep -E "^(backend/|mobile/)" | head -1 || true)
doc_changed=$(echo "$staged_files" | grep -E "^(docs/|\.agent/)" | head -1 || true)

if [[ -n "$code_changed" && -z "$doc_changed" ]]; then
  die "Code changed without documentation update. Stage a file in docs/ or .agent/ before closing."
fi

# ── Commit ────────────────────────────────────────────────────────────────────

COMMIT_MSG="${PHASE}

Session: ${SLUG}
Branch: ${CURRENT}

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git commit -m "$COMMIT_MSG"
COMMIT_SHA=$(git rev-parse --short HEAD)
info "Committed: $COMMIT_SHA"

# ── Push ──────────────────────────────────────────────────────────────────────

git push origin "$CURRENT"
info "Pushed: $CURRENT"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "Session closed successfully."
echo "  Session: $SLUG"
echo "  Commit:  $COMMIT_SHA"
echo "  Branch:  $CURRENT"
echo ""
echo "Next step: open a PR on GitHub"
echo "  gh pr create --base develop --head $CURRENT --title \"$PHASE\""
