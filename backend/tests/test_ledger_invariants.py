import os
import re
from pathlib import Path


APP_SERVICES_DIR = Path(__file__).resolve().parents[1] / "app" / "services"
APPROVED_MUTATION_FILES = {
    "dispatch_entry.py",
    "stock_entry.py",
    "rejection_entry.py",
    "reconciliation.py",
}
DIRECT_BATCH_MUTATION_PATTERN = re.compile(r"batch\.quantity\s*(?:=|\+=|-=)")


def test_no_direct_batch_mutation():
    violations: list[str] = []

    for file_path in APP_SERVICES_DIR.glob("*.py"):
        if file_path.name in APPROVED_MUTATION_FILES:
            continue

        content = file_path.read_text(encoding="utf-8")
        for lineno, line in enumerate(content.splitlines(), start=1):
            if DIRECT_BATCH_MUTATION_PATTERN.search(line):
                rel_path = os.path.relpath(file_path, APP_SERVICES_DIR.parents[1])
                violations.append(f"{rel_path}:{lineno}: {line.strip()}")

    assert not violations, "\n".join(violations)
