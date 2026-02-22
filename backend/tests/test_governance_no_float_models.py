import ast
import re
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
MODELS_ROOT = BACKEND_ROOT / "app" / "db" / "models"
SCHEMAS_ROOT = BACKEND_ROOT / "app" / "db" / "schemas"
VIEWS_ROOT = BACKEND_ROOT / "app" / "db" / "views"

ALLOWED_FLOAT_MODEL_FILES = {
    "item_burn_rate.py",
    "stock_depletion_forecast.py",
}

FLOAT_COLUMN_PATTERNS = (
    re.compile(r"Column\(\s*Float\b"),
    re.compile(r"Column\(\s*sa\.Float\b"),
)


def test_no_float_columns_in_models_except_forecast() -> None:
    violations: list[str] = []

    for path in sorted(MODELS_ROOT.rglob("*.py")):
        if path.name in ALLOWED_FLOAT_MODEL_FILES:
            continue

        source = path.read_text(encoding="utf-8")
        for pattern in FLOAT_COLUMN_PATTERNS:
            if pattern.search(source):
                violations.append(str(path.relative_to(BACKEND_ROOT)))
                break

        tree = ast.parse(source, filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            if not isinstance(node.func, ast.Name) or node.func.id != "Column":
                continue
            if not node.args:
                continue
            first = node.args[0]
            is_float_type = (
                isinstance(first, ast.Name)
                and first.id == "Float"
                or isinstance(first, ast.Call)
                and isinstance(first.func, ast.Attribute)
                and first.func.attr == "Float"
            )
            if is_float_type:
                violations.append(str(path.relative_to(BACKEND_ROOT)))
                break

    assert not violations, "Float model columns are not allowed: " + ", ".join(
        sorted(set(violations))
    )


def test_no_float_schema_annotations_except_forecast() -> None:
    violations: list[str] = []

    for path in sorted(SCHEMAS_ROOT.rglob("*.py")):
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source, filename=str(path))

        for node in ast.walk(tree):
            if not isinstance(node, ast.AnnAssign):
                continue

            annotation = node.annotation
            is_float_annotation = (
                isinstance(annotation, ast.Name) and annotation.id == "float"
            )
            if not is_float_annotation and isinstance(annotation, ast.Subscript):
                # Handles Optional[float], list[float], etc.
                names = [n.id for n in ast.walk(annotation) if isinstance(n, ast.Name)]
                is_float_annotation = "float" in names

            if is_float_annotation:
                violations.append(str(path.relative_to(BACKEND_ROOT)))
                break

    assert not violations, "Float schema annotations are not allowed: " + ", ".join(
        sorted(set(violations))
    )


def test_no_double_precision_in_view_sql_definitions() -> None:
    violations: list[str] = []

    for path in sorted(VIEWS_ROOT.rglob("*.sql")):
        source = path.read_text(encoding="utf-8").lower()
        if "double precision" in source:
            violations.append(str(path.relative_to(BACKEND_ROOT)))

    assert not violations, (
        "double precision found in view SQL definitions: " + ", ".join(violations)
    )
