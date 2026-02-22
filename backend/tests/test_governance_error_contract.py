import re
from pathlib import Path

from app.core.exceptions import AppException, register_exception_handlers
from fastapi import FastAPI
from fastapi.testclient import TestClient

RULE_ID_PATTERN = re.compile(r"^[A-Z]{3}-\d{3}$")
API_ROOT = Path(__file__).resolve().parents[1] / "app" / "api"


def _assert_error_envelope(response) -> None:
    body = response.json()
    assert "detail" in body
    assert "rule_id" in body
    assert "metadata" in body
    assert isinstance(body["detail"], str)
    assert isinstance(body["rule_id"], str)
    assert RULE_ID_PATTERN.match(body["rule_id"])
    assert body["metadata"] is None or isinstance(body["metadata"], dict)


def test_all_api_errors_have_rule_id_format() -> None:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/validation")
    def validation(value: int):
        return {"value": value}

    @app.get("/known-app-exception")
    def known_app_exception():
        raise AppException(
            detail="Known contract exception",
            status_code=409,
            rule_id="GEN-001",
            metadata={"case": "known"},
        )

    @app.get("/generic-exception")
    def generic_exception():
        raise RuntimeError("Unexpected failure")

    client = TestClient(app, raise_server_exceptions=False)

    validation_response = client.get("/validation", params={"value": "invalid"})
    assert validation_response.status_code == 422
    _assert_error_envelope(validation_response)
    assert not isinstance(validation_response.json()["detail"], list)

    known_response = client.get("/known-app-exception")
    assert known_response.status_code == 409
    _assert_error_envelope(known_response)

    generic_response = client.get("/generic-exception")
    assert generic_response.status_code == 500
    _assert_error_envelope(generic_response)


def test_no_raw_http_exception_leaks() -> None:
    violations = []
    pattern = re.compile(r"\braise\s+HTTPException\s*\(")

    for path in sorted(API_ROOT.rglob("*.py")):
        content = path.read_text(encoding="utf-8")
        if pattern.search(content):
            violations.append(
                str(path.relative_to(Path(__file__).resolve().parents[1]))
            )

    assert not violations, (
        "Raw HTTPException raises found in router modules:\n" + "\n".join(violations)
    )
