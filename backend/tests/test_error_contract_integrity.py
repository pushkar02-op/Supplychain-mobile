from pathlib import Path

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.core.exceptions import AppException, register_exception_handlers


def _build_test_client() -> TestClient:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/app-exception")
    def raise_app_exception():
        raise AppException(
            detail="Rule violation",
            status_code=409,
            rule_id="INV-001",
            metadata={"scope": "integrity"},
        )

    @app.get("/validation")
    def raise_validation(value: int):
        return {"value": value}

    @app.get("/http-exception")
    def raise_http_exception():
        raise HTTPException(status_code=404, detail="Not found")

    @app.get("/generic")
    def raise_generic():
        raise RuntimeError("Unhandled boom")

    @app.get("/metadata-default")
    def raise_with_default_metadata():
        raise AppException(
            detail="Default metadata", status_code=400, rule_id="ORD-007"
        )

    return TestClient(app, raise_server_exceptions=False)


def test_app_exception_returns_strict_envelope():
    client = _build_test_client()
    response = client.get("/app-exception")
    payload = response.json()

    assert response.status_code == 409
    assert payload["detail"] == "Rule violation"
    assert payload["rule_id"] == "INV-001"
    assert payload["metadata"] == {"scope": "integrity"}
    assert sorted(payload.keys()) == ["detail", "metadata", "rule_id"]


def test_validation_error_returns_strict_envelope():
    client = _build_test_client()
    response = client.get("/validation", params={"value": "bad"})
    payload = response.json()

    assert response.status_code == 422
    assert payload["detail"] == "Request validation failed"
    assert payload["rule_id"] == "GEN-422"
    assert isinstance(payload["metadata"], dict)
    assert sorted(payload.keys()) == ["detail", "metadata", "rule_id"]


def test_http_exception_returns_strict_envelope():
    client = _build_test_client()
    response = client.get("/http-exception")
    payload = response.json()

    assert response.status_code == 404
    assert payload["detail"] == "Not found"
    assert payload["rule_id"] == "GEN-HTTP"
    assert isinstance(payload["metadata"], dict)
    assert sorted(payload.keys()) == ["detail", "metadata", "rule_id"]


def test_generic_exception_returns_strict_envelope():
    client = _build_test_client()
    response = client.get("/generic")
    payload = response.json()

    assert response.status_code == 500
    assert payload["rule_id"] == "GEN-500"
    assert isinstance(payload["detail"], str)
    assert isinstance(payload["metadata"], dict)
    assert sorted(payload.keys()) == ["detail", "metadata", "rule_id"]


def test_rule_id_regex_enforced_at_exception_construction():
    with pytest.raises(ValueError):
        AppException(detail="Invalid rule id", status_code=400, rule_id="INV-1")


def test_metadata_always_present():
    client = _build_test_client()
    response = client.get("/metadata-default")
    payload = response.json()

    assert response.status_code == 400
    assert payload["rule_id"] == "ORD-007"
    assert payload["metadata"] == {}
    assert sorted(payload.keys()) == ["detail", "metadata", "rule_id"]


def test_representative_error_paths_always_include_contract_keys():
    client = _build_test_client()
    paths = ["/validation?value=bad", "/app-exception", "/http-exception", "/generic"]

    for path in paths:
        response = client.get(path)
        payload = response.json()
        assert {"detail", "rule_id", "metadata"}.issubset(payload.keys())
        assert isinstance(payload["rule_id"], str)
        assert isinstance(payload["metadata"], dict)


def test_no_direct_http_exception_raise_in_backend_app():
    app_root = Path(__file__).resolve().parents[1] / "app"
    violations = []

    for source_file in app_root.rglob("*.py"):
        source = source_file.read_text(encoding="utf-8")
        if "raise HTTPException(" in source:
            violations.append(str(source_file.relative_to(app_root.parent)))

    assert violations == []
