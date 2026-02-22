import ast
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
SERVICES_ROOT = BACKEND_ROOT / "app" / "services"

SCOPED_SERVICE_FILES = [
    "auth.py",
    "dispatch_entry.py",
    "mart_bill.py",
    "reconciliation.py",
    "stock_entry.py",
    "event_relay.py",
]

EXPECTED_ROLLBACK_WRAPPERS = {
    "auth.py": [
        "register_user",
        "login_user",
        "create_refresh_token",
        "refresh_token",
    ],
    "dispatch_entry.py": [
        "create_reversal_entry",
        "create_dispatch_entry",
        "create_dispatch_from_order",
    ],
    "mart_bill.py": [
        "save_and_process_mart_bill",
        "update_mart_bill",
        "verify_mart_bill",
        "unverify_mart_bill",
        "delete_mart_bill",
        "replace_mart_bill_file",
    ],
    "reconciliation.py": ["create_drift_record", "resolve_drift"],
    "stock_entry.py": [
        "create_stock_entry",
        "create_stock_adjustment",
        "delete_stock_entry",
    ],
    "event_relay.py": ["process_pending_events"],
}


def _db_method_call_count(function_node: ast.AST, method_name: str) -> int:
    count = 0
    for node in ast.walk(function_node):
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "db"
            and node.func.attr == method_name
        ):
            count += 1
    return count


def test_no_multiple_commit_calls_per_service_function() -> None:
    violations = []

    for filename in SCOPED_SERVICE_FILES:
        path = SERVICES_ROOT / filename
        tree = ast.parse(path.read_text(encoding="utf-8"))

        for node in tree.body:
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            commit_calls = _db_method_call_count(node, "commit")
            if commit_calls > 1:
                violations.append(f"{path.name}:{node.lineno}:{node.name}")

    assert not violations, (
        "Multiple db.commit() calls detected in a single service function:\n"
        + "\n".join(violations)
    )


def test_rollback_present_in_exception_paths() -> None:
    violations = []

    for filename, wrappers in EXPECTED_ROLLBACK_WRAPPERS.items():
        path = SERVICES_ROOT / filename
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)
        source_lines = source.splitlines()
        function_index = {
            node.name: node
            for node in tree.body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        }

        for wrapper in wrappers:
            node = function_index.get(wrapper)
            if node is None:
                violations.append(f"{filename}:missing function {wrapper}")
                continue

            start = node.lineno - 1
            end = getattr(node, "end_lineno", node.lineno)
            function_source = "\n".join(source_lines[start:end])

            if "db.rollback(" not in function_source:
                violations.append(f"{filename}:{wrapper}:missing db.rollback()")

    assert not violations, (
        "Rollback guards missing in expected wrapper functions:\n"
        + "\n".join(violations)
    )
