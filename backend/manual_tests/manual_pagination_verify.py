import sys
import os
from decimal import Decimal
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add app to path
sys.path.append("/app")

from app.db.base import Base
from app.db.models.item import Item
from app.db.models.batch import Batch
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.uom import UOM
from app.services.stock_entry import create_stock_entry
from app.services.rejection_entry import (
    create_rejection_entry,
    get_rejections_by_date_and_items,
)
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.schemas.rejection_entry import RejectionEntryCreate, RejectionPagination


def run_verify():
    print("Initializing In-Memory DB...")
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
        source="Test Vendor",
    )
    receipt = create_stock_entry(session, entry, created_by=1)
    batch_id = receipt.batch_id

    print("1. Seeding 15 rejections...")
    today = date.today()
    for i in range(15):
        create_rejection_entry(
            session,
            RejectionEntryCreate(
                batch_id=batch_id,
                quantity=Decimal("1.0"),
                unit="kg",
                reason=f"Reason {i}",
                rejection_date=today,
                rejected_by="tester",
            ),
        )

    # 2. Page 1 (Limit 10)
    print("2. Fetching Page 1 (0-10)...")
    page1 = get_rejections_by_date_and_items(
        session, rejection_date=today, skip=0, limit=10
    )
    # page1 is a dict now
    print(f"   Returned {len(page1['items'])} items (Expected 10)")
    print(f"   Total: {page1['total']} (Expected 15)")
    print(f"   Has More: {page1['has_more']} (Expected True)")

    assert len(page1["items"]) == 10
    assert page1["total"] == 15
    assert page1["has_more"] is True
    assert page1["skip"] == 0
    assert page1["limit"] == 10

    # 3. Page 2 (Limit 10 -> Should get 5)
    print("3. Fetching Page 2 (10-20)...")
    page2 = get_rejections_by_date_and_items(
        session, rejection_date=today, skip=10, limit=10
    )
    print(f"   Returned {len(page2['items'])} items (Expected 5)")
    print(f"   Total: {page2['total']} (Expected 15)")
    print(f"   Has More: {page2['has_more']} (Expected False)")

    assert len(page2["items"]) == 5
    assert page2["total"] == 15
    assert page2["has_more"] is False
    assert page2["skip"] == 10

    print("SUCCESS: Pagination Logic Verified.")


if __name__ == "__main__":
    try:
        run_verify()
    except Exception as e:
        print(f"CRASH: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)
