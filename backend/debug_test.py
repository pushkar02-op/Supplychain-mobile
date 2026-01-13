from datetime import date
from decimal import Decimal

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.mart import Mart
from app.db.models.stock_entry import StockEntry
from app.db.models.uom import UOM
from app.db.schemas.stock_entry import StockEntryCreate
from app.services.inventory_truth import calculate_ledger_balance, get_drift_report
from app.services.stock_entry import create_stock_entry


def run_test():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    print("Setting up DB...")
    uom_kg = UOM(code="kg", description="Kilogram")
    uom_g = UOM(code="g", description="Gram")
    session.add_all([uom_kg, uom_g])
    session.flush()

    item = Item(name="Rice", default_uom_id=uom_kg.id, item_code="RICE001")
    session.add(item)
    session.flush()

    mapping = ItemConversionMap(
        item_id=item.id,
        source_unit="g",
        target_unit="kg",
        conversion_factor=0.001,
        created_by="test",
    )
    session.add(mapping)
    session.commit()

    print("Running Stock Entry...")
    entry_data = StockEntryCreate(
        item_id=item.id,
        quantity=10,
        unit="kg",
        received_date=date.today(),
        price_per_unit=100.0,
        total_cost=1000.0,
        source="Vendor",
    )

    stock_entry = create_stock_entry(session, entry_data, created_by=1)
    print(f"Stock Entry Created: {stock_entry.id}")

    bal = calculate_ledger_balance(session, stock_entry.batch_id)
    print(f"Balance: {bal}")

    if bal != Decimal("10.000"):
        print("FAIL: Balance mismatch")
    else:
        print("PASS: Balance match")

    print("Running Drift Check...")
    report = get_drift_report(session, stock_entry.batch_id)
    print(f"Report: {report}")


if __name__ == "__main__":
    try:
        run_test()
    except Exception as e:
        import traceback

        traceback.print_exc()
