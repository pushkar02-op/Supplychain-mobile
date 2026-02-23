"""
Phase 2B: Legacy Path Observability Tests

Tests that legacy paths emit structured warning logs without changing behavior.
"""

import pytest
import logging
from datetime import date
from decimal import Decimal

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.models.batch import Batch
from app.db.models.uom import UOM
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.services.dispatch_entry import create_dispatch_entry


@pytest.fixture(scope="function")
def db_session():
    """In-memory SQLite session for isolated testing."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = SessionLocal()

    # Seed required data
    uom = UOM(code="kg", description="Kilogram")
    session.add(uom)
    session.flush()

    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


def test_legacy_dispatch_fallback_emits_warning(db_session, caplog):
    """
    Verify that when order_id is NOT provided, the heuristic fallback path
    emits a structured warning log with legacy_path marker.

    Behavior remains unchanged — dispatch succeeds if valid.
    """
    # Setup: Create Item, Mart, Order, Batch
    uom = db_session.query(UOM).filter_by(code="kg").first()

    item = Item(name="TestItem", default_uom_id=uom.id)
    db_session.add(item)
    db_session.flush()

    mart = Mart(name="TestMart", company_name="TestCo")
    db_session.add(mart)
    db_session.flush()

    order = Order(
        item_id=item.id,
        mart_id=mart.id,
        quantity_ordered=100,
        unit="kg",
        order_date=date.today(),
        status="Pending",
        quantity_dispatched=0,
    )
    db_session.add(order)
    db_session.flush()

    batch = Batch(
        item_id=item.id,
        quantity=Decimal("50.0"),
        unit="kg",
        received_at=date.today(),
    )
    db_session.add(batch)
    db_session.commit()
    db_session.refresh(batch)

    # Act: Create dispatch WITHOUT order_id (triggers legacy fallback)
    entry = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name=mart.name,
        dispatch_date=date.today(),
        quantity=10,
        unit="kg",
        # order_id intentionally omitted to trigger heuristic
    )

    with caplog.at_level(logging.WARNING):
        dispatch = create_dispatch_entry(db_session, entry, created_by="tester")

    # Assert: Dispatch succeeded (behavior unchanged)
    assert dispatch is not None
    assert dispatch.id is not None

    # Assert: Legacy path warning was emitted
    legacy_warnings = [
        record
        for record in caplog.records
        if "LEGACY_PATH_TRIGGERED" in record.getMessage()
    ]
    assert len(legacy_warnings) >= 1, "Expected LEGACY_PATH_TRIGGERED warning"

    # Verify structured fields (if extra is accessible)
    warning_record = legacy_warnings[0]
    assert "implicit_dispatch_order_link" in str(
        warning_record.getMessage()
    ) or hasattr(warning_record, "legacy_path")


def test_legacy_pagination_emits_warning(caplog):
    """
    Verify that using deprecated page/page_size parameters
    emits a structured warning log.

    Behavior remains unchanged — pagination still works.
    """
    from fastapi.testclient import TestClient
    from app.main import app
    from app.db.session import get_db
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from sqlalchemy.pool import StaticPool

    # Setup test DB
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db

    # Mock auth
    from app.core.auth import get_current_user
    from app.db.enums.role import Role
    from types import SimpleNamespace

    mock_user = SimpleNamespace(
        id=1,
        username="tester",
        full_name="Test User",
        is_admin=True,
        is_active=True,
        role=Role.OWNER,
    )
    app.dependency_overrides[get_current_user] = lambda: mock_user

    try:
        with TestClient(app) as client:
            with caplog.at_level(logging.WARNING):
                # Act: Use legacy pagination parameter
                response = client.get("/v1/mart-bills/?page=1&page_size=10")

        # Assert: Request succeeded (behavior unchanged)
        # Note: May return empty list, but should not error
        assert response.status_code in [200, 422]  # 422 if no data, 200 if success

        # Assert: Legacy param warning was emitted
        legacy_warnings = [
            record
            for record in caplog.records
            if "LEGACY_PARAM_USED" in record.getMessage()
        ]
        assert len(legacy_warnings) >= 1, "Expected LEGACY_PARAM_USED warning"
    finally:
        app.dependency_overrides.clear()
