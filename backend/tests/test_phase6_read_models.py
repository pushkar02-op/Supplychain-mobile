from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.models.warehouse import Warehouse
from app.db.models.views.batch_ledger_balance import BatchLedgerBalance
from app.db.models.views.inventory_signal import InventorySignal


@pytest.fixture(scope="function")
def db_session():
    """
    Isolated SQLite session and recreated read-model views.
    """
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SessionLocal = sessionmaker(bind=engine)
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()
    session.add(Warehouse(name="Main Warehouse", code="MAIN", is_active=True))
    session.commit()

    for object_name in ("batch_ledger_balance_view", "inventory_signal_view"):
        try:
            session.execute(text(f"DROP VIEW IF EXISTS {object_name}"))
        except Exception:
            session.rollback()
        try:
            session.execute(text(f"DROP TABLE IF EXISTS {object_name}"))
        except Exception:
            session.rollback()

    session.execute(
        text(
            """
            CREATE VIEW batch_ledger_balance_view AS
            SELECT
                warehouse_id,
                batch_id,
                ROUND(
                    SUM(
                        CASE
                            WHEN txn_type = 'IN' THEN base_qty
                            WHEN txn_type = 'OUT' THEN -base_qty
                            WHEN txn_type = 'ADJUST' THEN base_qty
                            ELSE 0
                        END
                    ),
                    3
                ) AS ledger_qty
            FROM inventory_txn
            WHERE batch_id IS NOT NULL
            GROUP BY warehouse_id, batch_id
            """
        )
    )
    session.execute(
        text(
            """
            CREATE VIEW inventory_signal_view AS
            SELECT
                warehouse_id,
                item_id,
                ROUND(
                    SUM(
                        CASE
                            WHEN txn_type = 'OUT'
                                 AND date(created_at) >= date('now', '-7 day')
                            THEN base_qty
                            ELSE 0
                        END
                    ),
                    3
                ) AS out_last_7d,
                ROUND(
                    SUM(
                        CASE
                            WHEN txn_type = 'OUT'
                                 AND date(created_at) < date('now', '-7 day')
                                 AND date(created_at) >= date('now', '-14 day')
                            THEN base_qty
                            ELSE 0
                        END
                    ),
                    3
                ) AS out_prev_7d
            FROM inventory_txn
            GROUP BY warehouse_id, item_id
            """
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()


def create_item(db, name="Test Item", unit="kg"):
    # Ensure UOM exists
    uom = db.query(UOM).filter(UOM.code == unit).first()
    if not uom:
        uom = UOM(code=unit, description=unit)
        db.add(uom)
        db.commit()
        db.refresh(uom)

    # Use unique name to avoid collisions
    unique_name = f"{name} {datetime.utcnow().timestamp()}"
    item = Item(name=unique_name, default_uom_id=uom.id)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def create_batch(db, item_id, qty=100.0, unit="kg"):
    batch = Batch(
        item_id=item_id,
        warehouse_id=1,
        quantity=qty,
        unit=unit,
        received_at=datetime.utcnow(),
    )
    db.add(batch)
    db.commit()
    db.refresh(batch)
    return batch


def create_txn(db, item_id, batch_id, txn_type, qty, unit="kg", days_ago=0):
    created_at = datetime.utcnow() - timedelta(days=days_ago)
    txn = InventoryTxn(
        item_id=item_id,
        batch_id=batch_id,
        warehouse_id=1,
        txn_type=txn_type,
        raw_qty=qty,
        raw_unit=unit,
        base_qty=qty,
        base_unit=unit,
        created_at=created_at,
    )
    db.add(txn)
    db.commit()
    db.refresh(txn)
    # Hack to force created_at (since default is server time)
    # We update it manually after create
    txn.created_at = created_at
    db.commit()
    return txn


def test_batch_ledger_balance_view(db_session):
    """
    Verify BatchLedgerBalance view sums transactions correctly.
    """
    db = db_session
    item = create_item(db, "LedgerTest")
    batch = create_batch(db, item.id)

    # 1. Add IN txn (+50)
    create_txn(db, item.id, batch.id, "IN", 50.0)

    # 2. Add OUT txn (-20)
    create_txn(db, item.id, batch.id, "OUT", 20.0)

    # 3. Add ADJUST (+5)
    create_txn(db, item.id, batch.id, "ADJUST", 5.0)

    # Expected: 50 - 20 + 5 = 35.

    # Verify View (Must query fresh)
    # Since we committed, the view should see it.

    balance = db.get(BatchLedgerBalance, (1, batch.id))
    assert balance is not None
    assert float(balance.ledger_qty) == 35.0


def test_inventory_signal_view(db_session):
    """
    Verify InventorySignal view buckets correctly.
    """
    db = db_session
    item = create_item(db, "SignalTest")

    # Last 7 days (e.g. 2 days ago) -> 10.0
    create_txn(db, item.id, None, "OUT", 10.0, days_ago=2)

    # Prev 7 days (e.g. 10 days ago) -> 5.0
    create_txn(db, item.id, None, "OUT", 5.0, days_ago=10)

    # Too old (e.g. 20 days ago) -> 100.0 (Should be ignored)
    create_txn(db, item.id, None, "OUT", 100.0, days_ago=20)

    # Verify View
    sig = db.get(InventorySignal, (1, item.id))
    assert sig is not None
    # Depending on float/decimal mapping, use float for compare
    assert float(sig.out_last_7d) == 10.0
    assert float(sig.out_prev_7d) == 5.0
