import json
import logging
from datetime import date
from decimal import Decimal
from uuid import UUID

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.correlation import (
    CorrelationIdMiddleware,
    reset_correlation_id,
    set_correlation_id,
)
from app.core.exceptions import AppException, register_exception_handlers
from app.core.structured_logging import log_event
from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.services.forecasting import refresh_forecast_for_item
from app.services.reconciliation import create_drift_record, resolve_drift


def _structured_payloads(caplog):
    payloads = []
    for record in caplog.records:
        try:
            payloads.append(json.loads(record.getMessage()))
        except json.JSONDecodeError:
            continue
    return payloads


def test_correlation_id_middleware_adds_header():
    app = FastAPI()
    app.add_middleware(CorrelationIdMiddleware)

    @app.get("/ping")
    def ping():
        return {"ok": True}

    with TestClient(app) as client:
        response = client.get("/ping")

    assert response.status_code == 200
    assert "X-Correlation-ID" in response.headers
    UUID(response.headers["X-Correlation-ID"])


def test_correlation_id_middleware_preserves_existing_header():
    app = FastAPI()
    app.add_middleware(CorrelationIdMiddleware)

    @app.get("/ping")
    def ping():
        return {"ok": True}

    with TestClient(app) as client:
        response = client.get("/ping", headers={"X-Correlation-ID": "custom-cid-123"})

    assert response.status_code == 200
    assert response.headers["X-Correlation-ID"] == "custom-cid-123"


def test_app_exception_logs_structured_entry(caplog):
    app = FastAPI()
    app.add_middleware(CorrelationIdMiddleware)
    register_exception_handlers(app)

    @app.get("/boom")
    def boom():
        raise AppException(
            detail="observability failure",
            status_code=400,
            rule_id="INV-001",
            metadata={"scope": "test"},
        )

    caplog.set_level(logging.ERROR, logger="app.structured")
    with TestClient(app) as client:
        response = client.get("/boom")

    assert response.status_code == 400
    payloads = _structured_payloads(caplog)
    entry = next(p for p in payloads if p.get("event") == "app_exception")
    assert entry["rule_id"] == "INV-001"
    assert entry["metadata"] == {"scope": "test"}
    assert entry["correlation_id"] is not None


def test_log_event_includes_correlation_id(caplog):
    caplog.set_level(logging.INFO, logger="app.structured")
    token = set_correlation_id("cid-observability-test")
    try:
        log_event(level="INFO", event="manual_event", metadata={"source": "unit_test"})
    finally:
        reset_correlation_id(token)

    payloads = _structured_payloads(caplog)
    entry = next(p for p in payloads if p.get("event") == "manual_event")
    assert entry["correlation_id"] == "cid-observability-test"
    assert entry["metadata"] == {"source": "unit_test"}


def test_drift_resolved_emits_log(db_session, caplog):
    uom = UOM(code="UNT", description="Unit")
    db_session.add(uom)
    db_session.commit()

    item = Item(name="Obs Drift Item", item_code="OBSDRIFT", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    batch = Batch(item_id=item.id, quantity=Decimal("100.0"), unit="UNT")
    db_session.add(batch)
    db_session.commit()

    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("110.0"),
            raw_unit="UNT",
            base_qty=Decimal("110.0"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    record = create_drift_record(db_session, batch.id)
    assert record is not None

    caplog.set_level(logging.INFO, logger="app.structured")
    result = resolve_drift(
        db_session,
        record.id,
        adjustment_qty=Decimal("-10.0"),
        user_id=42,
        apply_to_batch=False,
    )

    assert result["status"] == "success"
    payloads = _structured_payloads(caplog)
    entry = next(p for p in payloads if p.get("event") == "drift_resolved")
    assert entry["metadata"]["record_id"] == record.id
    assert entry["metadata"]["batch_id"] == batch.id
    assert entry["metadata"]["resolved_by"] == 42


def test_forecast_refreshed_emits_log(db_session, caplog):
    uom = UOM(code="KG", description="Kilogram")
    db_session.add(uom)
    db_session.commit()

    item = Item(name="Obs Forecast Item", item_code="OBSFCAST", default_uom_id=uom.id)
    db_session.add(item)
    db_session.commit()

    batch = Batch(
        item_id=item.id,
        quantity=Decimal("50.0"),
        unit="KG",
        received_at=date.today(),
    )
    db_session.add(batch)
    db_session.commit()

    caplog.set_level(logging.INFO, logger="app.structured")
    result = refresh_forecast_for_item(db_session, item.id)

    assert result["item_id"] == item.id
    payloads = _structured_payloads(caplog)
    entry = next(p for p in payloads if p.get("event") == "forecast_refreshed")
    assert entry["metadata"]["item_id"] == item.id
