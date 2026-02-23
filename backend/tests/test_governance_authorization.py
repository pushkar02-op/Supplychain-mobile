import ast
import re
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
API_ROOT = BACKEND_ROOT / "app" / "api"
HTTP_METHODS = {"get", "post", "put", "patch", "delete"}


def _is_router_http_decorator(node: ast.AST) -> bool:
    return (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr in HTTP_METHODS
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "router"
    )


def _has_admin_dependency_in_node(node: ast.AST) -> bool:
    return "Depends(require_role(Role.OWNER))" in ast.unparse(node)


def test_no_inline_admin_checks_in_routers() -> None:
    violations = []
    pattern = re.compile(r"\bif\s+not?\s*current_user\.is_admin\b")

    for path in sorted(API_ROOT.rglob("*.py")):
        content = path.read_text(encoding="utf-8")
        if pattern.search(content):
            violations.append(path.relative_to(BACKEND_ROOT).as_posix())

    assert not violations, "Inline admin checks found in router layer:\n" + "\n".join(
        violations
    )


def test_all_admin_routes_use_dependency() -> None:
    violations = []
    admin_files = sorted(API_ROOT.rglob("admin_*.py"))

    for path in admin_files:
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)
        for node in tree.body:
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue

            decorators = [
                d for d in node.decorator_list if _is_router_http_decorator(d)
            ]
            if not decorators:
                continue

            has_param_dependency = any(
                _has_admin_dependency_in_node(default)
                for default in node.args.defaults
                if isinstance(default, ast.Call)
            )

            has_decorator_dependency = any(
                any(
                    keyword.arg == "dependencies"
                    and _has_admin_dependency_in_node(keyword.value)
                    for keyword in decorator.keywords
                )
                for decorator in decorators
            )

            if not (has_param_dependency or has_decorator_dependency):
                rel = path.relative_to(BACKEND_ROOT).as_posix()
                violations.append(f"{rel}:{node.lineno}:{node.name}")

    assert not violations, (
        "Admin routes missing Depends(require_role(Role.OWNER)):\n"
        + "\n".join(violations)
    )
