import ast
import io
import json
import logging
from pathlib import Path

from app.core.correlation import reset_correlation_id, set_correlation_id
from app.core.structured_logging import JsonLogFormatter

BACKEND_ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = BACKEND_ROOT / "app"


def test_no_print_statements() -> None:
    violations = []

    for path in sorted(APP_ROOT.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "print"
            ):
                rel = path.relative_to(BACKEND_ROOT).as_posix()
                violations.append(f"{rel}:{node.lineno}")

    assert not violations, "print(...) usage found in backend app:\n" + "\n".join(
        violations
    )


def test_correlation_id_injected(client) -> None:
    response = client.get("/v1/orders")
    assert "X-Correlation-ID" in response.headers
    assert response.headers["X-Correlation-ID"]


def test_structured_logger_format() -> None:
    logger = logging.getLogger("governance.structured.format")
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setFormatter(JsonLogFormatter())

    previous_propagate = logger.propagate
    logger.propagate = False
    logger.handlers = [handler]
    logger.setLevel(logging.INFO)

    token = set_correlation_id("gov-correlation-id")
    try:
        logger.info("governance_probe")
    finally:
        reset_correlation_id(token)
        logger.handlers = []
        logger.propagate = previous_propagate

    raw = stream.getvalue().strip()
    payload = json.loads(raw)

    assert "timestamp" in payload
    assert payload.get("level") == "INFO"
    assert payload.get("event") == "governance_probe"
    assert payload.get("correlation_id") == "gov-correlation-id"
