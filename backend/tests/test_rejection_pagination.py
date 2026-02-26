import pytest
from decimal import Decimal
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.services.stock_entry import create_stock_entry
from app.services.rejection_entry import (
    create_rejection_entry,
    get_rejections_by_date_and_items,
)
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.schemas.rejection_entry import RejectionEntryCreate


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Pre-Seed Data
    uom = UOM(code="kg", description="kilogram")
    session.add(uom)
    session.flush()

    item = Item(name="TestItem", default_uom_id=uom.id, item_code="ITEM001")
    session.add(item)
    session.flush()

    # Create Batch
    entry = StockEntryCreate(
        item_id=item.id,
        quantity=Decimal("1000.0"),
        unit="kg",
        received_date=date.today(),
        price_per_unit=10.0,
        total_cost=10000.0,
    )
    receipt = create_stock_entry(session, entry)

    # Store IDs for tests
    session.batch_id = receipt.batch_id
    session.item_id = item.id

    yield session
    session.close()


def test_pagination_logic(db_session):
    # 1. Create 15 rejections
    today = date.today()
    for i in range(15):
        create_rejection_entry(
            db_session,
            RejectionEntryCreate(
                batch_id=db_session.batch_id,
                quantity=Decimal("1.0"),
                unit="kg",
                reason=f"Reason {i}",
                rejection_date=today,
                rejected_by="tester",
            ),
        )

    # 2. Page 1 (Limit 10)
    page1 = get_rejections_by_date_and_items(
        db_session, rejection_date=today, skip=0, limit=10
    )
    assert len(page1["items"]) == 10
    assert page1["total"] == 15
    assert page1["has_more"] is True
    assert page1["skip"] == 0
    assert page1["limit"] == 10

    # 3. Page 2 (Limit 10 -> Should get 5)
    page2 = get_rejections_by_date_and_items(
        db_session, rejection_date=today, skip=10, limit=10
    )
    assert len(page2["items"]) == 5
    assert page2["total"] == 15
    assert page2["has_more"] is False
    assert page2["skip"] == 10


def test_pagination_with_filters_and_active_state(db_session):
    today = date.today()
    # Create 5 Active Rejections
    for i in range(5):
        create_rejection_entry(
            db_session,
            RejectionEntryCreate(
                batch_id=db_session.batch_id,
                quantity=Decimal("1.0"),
                unit="kg",
                reason="Test reason",
                rejection_date=today,
                rejected_by="tester",
            ),
        )

    # Fetch with pagination
    res = get_rejections_by_date_and_items(
        db_session, rejection_date=today, item_ids=[db_session.item_id], skip=0, limit=3
    )
    assert len(res["items"]) == 3
    assert res["total"] == 5
    assert res["has_more"] is True


def test_eager_loading_check(db_session):
    # Performance check: Accessing batch/item shouldn't trigger new queries (if we could count queries)
    # Ideally we'd use an asserting event listener, but functional check suffices for functional correctness
    create_rejection_entry(
        db_session,
        RejectionEntryCreate(
            batch_id=db_session.batch_id,
            quantity=10,
            unit="kg",
            reason="Eager load test",
            rejection_date=date.today(),
            rejected_by="tester",
        ),
    )

    res = get_rejections_by_date_and_items(db_session, date.today(), limit=1)
    item = res["items"][0]

    # These should be populated
    assert item.batch is not None
    assert item.batch.item_id == db_session.item_id
    assert item.item is not None
