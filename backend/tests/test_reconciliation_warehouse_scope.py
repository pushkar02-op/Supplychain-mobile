from decimal import Decimal

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.warehouse import Warehouse
from app.services.reconciliation import create_drift_record, resolve_drift


def test_reconciliation_is_scoped_by_warehouse():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()

    w1 = Warehouse(name="Main Warehouse", code="MAIN", is_active=True)
    w2 = Warehouse(name="Secondary Warehouse", code="SEC", is_active=True)
    db.add_all([w1, w2])
    db.flush()

    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()
    item = Item(name="Recon Item", item_code="REC-ITEM", default_uom_id=uom.id)
    db.add(item)
    db.flush()

    batch = Batch(
        item_id=item.id, warehouse_id=w1.id, quantity=Decimal("100.000"), unit="kg"
    )
    db.add(batch)
    db.commit()

    record = create_drift_record(db, batch.id, warehouse_id=w1.id)
    assert record is not None
    assert record.warehouse_id == w1.id

    unauthorized = resolve_drift(
        db,
        record.id,
        adjustment_qty=Decimal("1.000"),
        user_id=1,
        apply_to_batch=False,
        warehouse_id=w2.id,
    )
    assert unauthorized["error"] == "Unauthorized warehouse access"

    authorized = resolve_drift(
        db,
        record.id,
        adjustment_qty=Decimal("1.000"),
        user_id=1,
        apply_to_batch=False,
        warehouse_id=w1.id,
    )
    assert authorized["status"] == "success"
    assert authorized["record"].warehouse_id == w1.id

    db.close()
