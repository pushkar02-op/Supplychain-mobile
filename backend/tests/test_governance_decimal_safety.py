import ast
import re
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
MODELS_ROOT = BACKEND_ROOT / "app" / "db" / "models"
SCHEMAS_ROOT = BACKEND_ROOT / "app" / "db" / "schemas"
SERVICES_ROOT = BACKEND_ROOT / "app" / "services"

# Legacy baseline: prevent new Float persistence from being introduced.
LEGACY_FLOAT_MODEL_ALLOWLIST = {
    "app/db/models/dispatch_entry.py",
    "app/db/models/dispatch_reversal.py",
    "app/db/models/item_burn_rate.py",
    "app/db/models/item_conversion_map.py",
    "app/db/models/mart_bill.py",
    "app/db/models/mart_bill_item.py",
    "app/db/models/order.py",
    "app/db/models/order_fulfillment_metrics.py",
    "app/db/models/reconciliation_mismatch.py",
    "app/db/models/stock_depletion_forecast.py",
    "app/db/models/stock_entry.py",
    "app/db/models/views/inventory_summary.py",
    "app/db/models/views/pnl_summary.py",
}


def _annotation_contains_float(node: ast.AST) -> bool:
    if isinstance(node, ast.Name):
        return node.id == "float"
    if isinstance(node, ast.Constant):
        return node.value == "float"
    if isinstance(node, ast.Subscript):
        return _annotation_contains_float(node.value) or _annotation_contains_float(
            node.slice
        )
    if isinstance(node, ast.BinOp):
        return _annotation_contains_float(node.left) or _annotation_contains_float(
            node.right
        )
    if isinstance(node, ast.Tuple):
        return any(_annotation_contains_float(elt) for elt in node.elts)
    if isinstance(node, ast.Attribute):
        return node.attr == "float"
    return False


def test_no_float_in_sqlalchemy_models() -> None:
    discovered = set()
    float_token = re.compile(r"\bFloat\b")

    for path in sorted(MODELS_ROOT.rglob("*.py")):
        content = path.read_text(encoding="utf-8")
        if float_token.search(content):
            discovered.add(path.relative_to(BACKEND_ROOT).as_posix())

    unexpected = sorted(discovered - LEGACY_FLOAT_MODEL_ALLOWLIST)
    assert not unexpected, (
        "New SQLAlchemy Float usage introduced outside legacy baseline:\n"
        + "\n".join(unexpected)
    )


def test_no_float_schema_fields() -> None:
    violations = []
    guarded_tokens = ("quantity", "price", "amount", "cost", "total", "rate")

    for path in sorted(SCHEMAS_ROOT.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if not isinstance(node, ast.AnnAssign):
                continue
            if not isinstance(node.target, ast.Name):
                continue
            field_name = node.target.id.lower()
            if not any(token in field_name for token in guarded_tokens):
                continue
            if _annotation_contains_float(node.annotation):
                rel = path.relative_to(BACKEND_ROOT).as_posix()
                violations.append(f"{rel}:{node.lineno} -> {node.target.id}")

    assert not violations, (
        "Float-typed quantity/price schema fields detected:\n" + "\n".join(violations)
    )


def test_no_float_cast_in_services() -> None:
    violations = []
    pattern = re.compile(r"\bfloat\s*\(")

    for path in sorted(SERVICES_ROOT.rglob("*.py")):
        content = path.read_text(encoding="utf-8")
        if pattern.search(content):
            rel = path.relative_to(BACKEND_ROOT).as_posix()
            violations.append(rel)

    assert not violations, "float(...) casts found in service layer:\n" + "\n".join(
        violations
    )
