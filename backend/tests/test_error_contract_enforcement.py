from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
import pytest

from app.core.exceptions import AppException, register_exception_handlers


def _build_test_client() -> TestClient:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/raise-http-exception")
    def raise_http_exception():
        raise HTTPException(status_code=418, detail="Teapot")

    @app.get("/raise-validation")
    def raise_validation(value: int):
        return {"value": value}

    @app.get("/raise-generic")
    def raise_generic():
        raise RuntimeError("Boom")

    @app.get("/raise-app-with-rule")
    def raise_app_with_rule():
        raise AppException(
            detail="Rule error",
            status_code=400,
            rule_id="INV-001",
            metadata={"scope": "test"},
        )

    @app.get("/raise-app-without-rule")
    def raise_app_without_rule():
        raise AppException(detail="No rule", status_code=400)

    return TestClient(app, raise_server_exceptions=False)


def test_http_exception_returns_structured_envelope():
    client = _build_test_client()
    response = client.get("/raise-http-exception")
    payload = response.json()

    assert response.status_code == 418
    assert payload == {"detail": "Teapot", "rule_id": None, "metadata": {}}


def test_request_validation_error_returns_structured_envelope():
    client = _build_test_client()
    response = client.get("/raise-validation", params={"value": "bad"})
    payload = response.json()

    assert response.status_code == 422
    assert payload == {
        "detail": "Request validation failed",
        "rule_id": None,
        "metadata": {},
    }


def test_generic_exception_returns_structured_envelope():
    client = _build_test_client()
    response = client.get("/raise-generic")
    payload = response.json()

    assert response.status_code == 500
    assert payload == {
        "detail": "Internal server error. Please contact support.",
        "rule_id": None,
        "metadata": {},
    }


def test_app_exception_with_rule_id_preserves_rule_id():
    client = _build_test_client()
    response = client.get("/raise-app-with-rule")
    payload = response.json()

    assert response.status_code == 400
    assert payload["detail"] == "Rule error"
    assert payload["rule_id"] == "INV-001"
    assert payload["metadata"] == {"scope": "test"}


def test_app_exception_without_rule_id_sets_rule_id_none():
    client = _build_test_client()
    response = client.get("/raise-app-without-rule")
    payload = response.json()

    assert response.status_code == 400
    assert payload["detail"] == "No rule"
    assert payload["rule_id"] is None
    assert payload["metadata"] == {}


def test_invalid_rule_id_format_raises_assertion_error():
    with pytest.raises(AssertionError):
        AppException(detail="Invalid", status_code=400, rule_id="bad-1")
