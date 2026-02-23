from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.exceptions import AppException
from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.warehouse import Warehouse
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.inventory_txn import create_inventory_txn


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    w1 = Warehouse(name="Main Warehouse", code="MAIN", is_active=True)
    w2 = Warehouse(name="Secondary Warehouse", code="SEC", is_active=True)
    session.add_all([w1, w2])
    session.flush()

    uom = UOM(code="kg", description="Kilogram")
    session.add(uom)
    session.flush()

    item = Item(name="Txn Item", item_code="TXN-ITEM", default_uom_id=uom.id)
    session.add(item)
    session.flush()

    batch = Batch(
        item_id=item.id,
        warehouse_id=w1.id,
        quantity=Decimal("100.000"),
        unit="kg",
    )
    session.add(batch)
    session.commit()

    yield session, item.id, batch.id, w1.id, w2.id
    session.close()


def test_inventory_txn_rejects_mismatched_batch_warehouse(db_session):
    db, item_id, batch_id, _, w2_id = db_session
    with pytest.raises(AppException) as exc:
        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=item_id,
                batch_id=batch_id,
                warehouse_id=w2_id,
                txn_type="IN",
                raw_qty=Decimal("1.000"),
                raw_unit="kg",
                base_qty=Decimal("1.000"),
                base_unit="kg",
            ),
        )
    assert exc.value.status_code == 409
    assert exc.value.rule_id == "INV-001"


def test_inventory_txn_derives_warehouse_from_batch(db_session):
    db, item_id, batch_id, w1_id, _ = db_session
    txn = create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=item_id,
            batch_id=batch_id,
            txn_type="OUT",
            raw_qty=Decimal("2.000"),
            raw_unit="kg",
            base_qty=Decimal("2.000"),
            base_unit="kg",
        ),
    )
    db.commit()
    assert txn.warehouse_id == w1_id
