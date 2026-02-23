from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICES_ROOT = ROOT / "app" / "services"

TARGET_FILES = [
    "stock_entry.py",
    "dispatch_entry.py",
    "rejection_entry.py",
    "order.py",
    "mart_bill.py",
    "mart_bill_item.py",
    "reconciliation.py",
    "reports.py",
    "batch.py",
    "stock_history.py",
    "inventory_txn.py",
]


def test_services_have_warehouse_scope_guards():
    missing = []
    for file_name in TARGET_FILES:
        source = (SERVICES_ROOT / file_name).read_text(encoding="utf-8")
        has_warehouse_arg = "warehouse_id" in source
        has_scope_guard = any(
            marker in source
            for marker in (
                "resolve_system_warehouse_id(",
                "validate_warehouse_access(",
                "warehouse_id is not None",
                "warehouse_id ==",
                "AUT-004",
            )
        )
        if not (has_warehouse_arg and has_scope_guard):
            missing.append(file_name)

    assert not missing, f"Service files missing warehouse scope patterns: {missing}"
