import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API_ROOT = ROOT / "app" / "api"

TARGET_FILES = [
    "stock_entry.py",
    "stock_adjustment.py",
    "stock_history.py",
    "dispatch_entry.py",
    "rejection_entry.py",
    "order.py",
    "mart_bill.py",
    "mart_bill_item.py",
    "invoice.py",
    "invoice_item.py",
    "inventory_txn.py",
    "reports.py",
    "admin_ledger.py",
    "admin_reconciliation.py",
    "admin_identity.py",
    "batch.py",
    "cost_control.py",
]

ROUTE_METHODS = {"post", "put", "patch", "delete"}
EXEMPT_ROUTES = {
    ("admin_identity.py", "create_mart_alias"),
}


def _route_method(node: ast.expr) -> str | None:
    if not isinstance(node, ast.Call):
        return None
    func = node.func
    if isinstance(func, ast.Attribute):
        return func.attr.lower()
    return None


def test_mutation_routes_use_warehouse_resolution():
    missing = []

    for file_name in TARGET_FILES:
        path = API_ROOT / file_name
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)

        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            methods = {
                method
                for dec in node.decorator_list
                for method in [_route_method(dec)]
                if method in ROUTE_METHODS
            }
            if not methods:
                continue

            if (file_name, node.name) in EXEMPT_ROUTES:
                continue

            segment = ast.get_source_segment(source, node) or ""
            if "resolve_warehouse_for_request(" not in segment:
                missing.append(f"{file_name}:{node.name}")

    assert not missing, f"Mutation routes missing warehouse resolution: {missing}"
