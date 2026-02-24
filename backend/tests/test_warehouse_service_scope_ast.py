import ast
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
    "inventory_truth.py",
    "item.py",
    "item_management.py",
    "cost_control.py",
    "kpi.py",
]

TRANSACTIONAL_MODELS = {
    "Batch",
    "StockEntry",
    "DispatchEntry",
    "RejectionEntry",
    "Order",
    "Invoice",
    "InvoiceItem",
    "InventoryTxn",
    "ReconciliationRecord",
    "MartBill",
    "MartBillItem",
    "LabourCostDaily",
    "TransportCostDaily",
}


def _query_model_name(query_call: ast.Call) -> str | None:
    if not query_call.args:
        return None
    arg = query_call.args[0]
    if isinstance(arg, ast.Name):
        return arg.id
    if isinstance(arg, ast.Attribute):
        return arg.attr
    return None


def _find_enclosing_function(tree: ast.AST, lineno: int):
    candidates = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and hasattr(
            node, "end_lineno"
        ):
            if node.lineno <= lineno <= node.end_lineno:
                candidates.append(node)
    if not candidates:
        return None
    return min(candidates, key=lambda n: n.end_lineno - n.lineno)


def _find_parent_stmt(node: ast.AST, parent_map: dict[ast.AST, ast.AST]):
    current = node
    while current and not isinstance(current, ast.stmt):
        current = parent_map.get(current)
    return current


def _has_intentionally_global_comment(lines: list[str], lineno: int) -> bool:
    start = max(0, lineno - 4)
    end = min(len(lines), lineno)
    for i in range(start, end):
        if "Intentionally global" in lines[i]:
            return True
    return False


def _is_allowed_intentionally_global(
    file_name: str,
    function_name: str,
    model_name: str,
    stmt_src: str,
    lines: list[str],
    lineno: int,
) -> bool:
    if not _has_intentionally_global_comment(lines, lineno):
        return False

    if file_name == "item.py" and function_name == "update_item":
        return model_name == "InventoryTxn"

    if file_name == "mart_bill.py" and function_name == "save_and_process_mart_bill":
        return model_name == "MartBill" and "file_hash" in stmt_src

    return False


def _is_explicitly_warehouse_scoped(stmt_src: str, model_name: str) -> bool:
    return f"{model_name}.warehouse_id" in stmt_src and "warehouse_id" in stmt_src


def _is_batch_fk_scoped(stmt_src: str) -> bool:
    return (
        ".batch_id ==" in stmt_src
        or "Batch.id == batch_id" in stmt_src
        or "Batch.id == entry.batch_id" in stmt_src
        or "Batch.id == rej.batch_id" in stmt_src
    )


def _is_param_scoped(function_node: ast.AST, fn_src: str) -> bool:
    if not isinstance(function_node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        return False

    arg_names = {arg.arg for arg in function_node.args.args}
    if "warehouse_id" not in arg_names:
        return False

    markers = (
        "resolve_system_warehouse_id(",
        "validate_warehouse_access(",
        "resolve_warehouse_for_request(",
        "warehouse_id is not None",
        ".warehouse_id ==",
        "warehouse_id=warehouse_id",
    )
    return any(marker in fn_src for marker in markers)


def test_services_have_per_query_warehouse_scope_guards():
    violations = []

    for file_name in TARGET_FILES:
        path = SERVICES_ROOT / file_name
        source = path.read_text(encoding="utf-8")
        lines = source.splitlines()
        tree = ast.parse(source)
        parent_map = {
            child: parent
            for parent in ast.walk(tree)
            for child in ast.iter_child_nodes(parent)
        }

        for node in ast.walk(tree):
            if not (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "query"
            ):
                continue

            model_name = _query_model_name(node)
            if model_name not in TRANSACTIONAL_MODELS:
                continue

            function_node = _find_enclosing_function(tree, node.lineno)
            function_name = function_node.name if function_node else "(module)"
            fn_src = (
                ast.get_source_segment(source, function_node)
                if function_node is not None
                else ""
            ) or ""

            stmt = _find_parent_stmt(node, parent_map)
            stmt_src = (ast.get_source_segment(source, stmt) if stmt else "") or ""

            if _is_explicitly_warehouse_scoped(stmt_src, model_name):
                continue
            if _is_batch_fk_scoped(stmt_src):
                continue
            if _is_param_scoped(function_node, fn_src):
                continue
            if _is_allowed_intentionally_global(
                file_name=file_name,
                function_name=function_name,
                model_name=model_name,
                stmt_src=stmt_src,
                lines=lines,
                lineno=node.lineno,
            ):
                continue

            compact_stmt = " ".join(stmt_src.split())
            violations.append(
                f"{file_name}:{node.lineno} {function_name} -> {model_name} :: {compact_stmt}"
            )

    assert not violations, "Unscoped transactional queries found:\n" + "\n".join(
        violations
    )


# ---------------------------------------------------------------------------
# Phase 6 (R1-4): Financial Lock Enforcement AST Guard
# ---------------------------------------------------------------------------

# Mapping: service file -> list of mutation functions that MUST call
# enforce_financial_lock() or enforce_lock_for_entity().
FINANCIAL_LOCK_ENFORCED_FUNCTIONS: dict[str, list[str]] = {
    "dispatch_entry.py": [
        "_create_dispatch_entry_impl",
        "_create_dispatch_from_order_impl",
        "create_reversal_entry",
    ],
    "stock_entry.py": [
        "_create_stock_entry_impl",
        "_create_stock_adjustment_impl",
        "_delete_stock_entry_impl",
    ],
    "rejection_entry.py": [
        "create_rejection_entry",
        "reverse_rejection_entry",
    ],
    "order.py": [
        "create_order",
        "update_order",
    ],
    "mart_bill.py": [
        "save_and_process_mart_bill",
        "_update_mart_bill_impl",
        "_verify_mart_bill_impl",
        "_delete_mart_bill_impl",
        "_replace_mart_bill_file_impl",
    ],
    "cost_control.py": [
        "upsert_labour_cost",
        "upsert_transport_cost",
    ],
    "reconciliation.py": [
        "_resolve_drift_impl",
    ],
}

LOCK_CALL_NAMES = {"enforce_financial_lock", "enforce_lock_for_entity"}


def _function_contains_lock_call(
    func_node: ast.FunctionDef | ast.AsyncFunctionDef,
) -> bool:
    """Return True if the function body contains a call to a financial lock function."""
    for node in ast.walk(func_node):
        if not isinstance(node, ast.Call):
            continue
        # Direct call: enforce_financial_lock(...)
        if isinstance(node.func, ast.Name) and node.func.id in LOCK_CALL_NAMES:
            return True
        # Attribute call: module.enforce_financial_lock(...)
        if isinstance(node.func, ast.Attribute) and node.func.attr in LOCK_CALL_NAMES:
            return True
    return False


def test_mutation_functions_have_financial_lock_enforcement():
    """AST guard: every mutation function listed in FINANCIAL_LOCK_ENFORCED_FUNCTIONS
    must contain a call to enforce_financial_lock() or enforce_lock_for_entity()."""
    missing = []

    for file_name, required_functions in FINANCIAL_LOCK_ENFORCED_FUNCTIONS.items():
        path = SERVICES_ROOT / file_name
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)

        # Build name -> node map for top-level functions
        func_map: dict[str, ast.FunctionDef | ast.AsyncFunctionDef] = {}
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                func_map[node.name] = node

        for func_name in required_functions:
            func_node = func_map.get(func_name)
            if func_node is None:
                missing.append(f"{file_name}::{func_name} — function not found")
                continue
            if not _function_contains_lock_call(func_node):
                missing.append(
                    f"{file_name}::{func_name} — missing enforce_financial_lock / enforce_lock_for_entity call"
                )

    assert not missing, (
        "Mutation functions missing financial lock enforcement:\n" + "\n".join(missing)
    )
