import ast
from pathlib import Path

SERVICES_ROOT = Path(__file__).resolve().parents[1] / "app" / "services"


def test_no_multiple_db_commits_per_function() -> None:
    violations: list[str] = []

    for path in sorted(SERVICES_ROOT.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in tree.body:
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue

            commit_calls = 0
            for child in ast.walk(node):
                if (
                    isinstance(child, ast.Call)
                    and isinstance(child.func, ast.Attribute)
                    and isinstance(child.func.value, ast.Name)
                    and child.func.value.id == "db"
                    and child.func.attr == "commit"
                ):
                    commit_calls += 1

            if commit_calls > 1:
                violations.append(
                    f"{path.relative_to(SERVICES_ROOT.parent)}:{node.name}:{commit_calls}"
                )

    assert not violations, "Multiple db.commit() calls found:\n" + "\n".join(violations)
