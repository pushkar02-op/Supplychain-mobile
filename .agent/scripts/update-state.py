#!/usr/bin/env python3
"""
update-state.py — Validate and apply a state delta to .agent/STATE/state.json.

Usage:
  python update-state.py --delta '{"phase": "FEATURE_X", "current_focus": "..."}'
  python update-state.py --delta-file /path/to/delta.json

The delta is a partial JSON object. Only the fields present in the delta
are updated. All other fields are preserved.

Required fields in state.json (schema_version 2):
  schema_version, updated_at, phase, current_focus,
  active_branches, subsystems, open_threads, recent_sessions, next_actions
"""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
STATE_FILE = REPO_ROOT / ".agent" / "STATE" / "state.json"

REQUIRED_FIELDS = {
    "schema_version",
    "updated_at",
    "phase",
    "current_focus",
    "active_branches",
    "subsystems",
    "open_threads",
    "recent_sessions",
    "next_actions",
}

ALLOWED_SUBSYSTEM_STATUSES = {"stable", "ux_transition", "refactor", "broken"}


def load_state() -> dict:
    if not STATE_FILE.exists():
        print(f"ERROR: {STATE_FILE} not found.", file=sys.stderr)
        sys.exit(1)
    with STATE_FILE.open() as f:
        return json.load(f)


def validate_state(state: dict) -> list[str]:
    errors = []
    missing = REQUIRED_FIELDS - set(state.keys())
    if missing:
        errors.append(f"Missing required fields: {sorted(missing)}")
    if state.get("schema_version") != 2:
        errors.append(f"schema_version must be 2, got: {state.get('schema_version')}")
    for name, sub in state.get("subsystems", {}).items():
        if "status" not in sub:
            errors.append(f"subsystem '{name}' missing 'status' field")
        elif sub["status"] not in ALLOWED_SUBSYSTEM_STATUSES:
            errors.append(
                f"subsystem '{name}' has invalid status '{sub['status']}'. "
                f"Allowed: {sorted(ALLOWED_SUBSYSTEM_STATUSES)}"
            )
        if "invariants_ok" not in sub:
            errors.append(f"subsystem '{name}' missing 'invariants_ok' field")
    return errors


def apply_delta(state: dict, delta: dict) -> dict:
    """Apply delta to state. Nested dicts are merged, not replaced."""
    result = dict(state)
    for key, value in delta.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = {**result[key], **value}
        else:
            result[key] = value
    result["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return result


def main():
    parser = argparse.ArgumentParser(description="Apply a state delta to state.json")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--delta", help="JSON string of the delta to apply")
    group.add_argument("--delta-file", help="Path to a JSON file containing the delta")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print result without writing"
    )
    args = parser.parse_args()

    # Load delta
    try:
        if args.delta:
            delta = json.loads(args.delta)
        else:
            with open(args.delta_file) as f:
                delta = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in delta: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(delta, dict):
        print("ERROR: Delta must be a JSON object.", file=sys.stderr)
        sys.exit(1)

    # Load and validate current state
    state = load_state()
    errors = validate_state(state)
    if errors:
        print("ERROR: Current state.json is invalid:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    # Apply delta
    new_state = apply_delta(state, delta)

    # Validate result
    errors = validate_state(new_state)
    if errors:
        print("ERROR: Delta would produce invalid state:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print("DRY RUN — result state.json would be:")
        print(json.dumps(new_state, indent=2))
        return

    with STATE_FILE.open("w") as f:
        json.dump(new_state, f, indent=2)
        f.write("\n")

    print(f"state.json updated. phase={new_state['phase']}")


if __name__ == "__main__":
    main()
