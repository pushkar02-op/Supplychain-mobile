import asyncio
from datetime import date, datetime
from decimal import Decimal
from io import BytesIO

import pandas as pd
import pytest
from fastapi import UploadFile

from app.core.exceptions import AppException
from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.order import Order
from app.db.models.reconciliation_record import DriftStatus, ReconciliationRecord
from app.db.models.uom import UOM
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.services.dispatch_entry import create_dispatch_entry
from app.services.mart_bill import save_and_process_mart_bill
from app.services.reconciliation import create_drift_record, resolve_drift


def _seed_dispatch_basics(db_session):
    uom = UOM(code="kg", description="Kilogram")
    db_session.add(uom)
    db_session.flush()

    item = Item(name="Atomic Dispatch Item", default_uom_id=uom.id, item_code="ADI-1")
    db_session.add(item)

    mart = Mart(name="Atomic Mart", company_name="Atomic Co")
    db_session.add(mart)
    db_session.flush()

    batch = Batch(
        item_id=item.id,
        quantity=Decimal("100.000"),
        unit="kg",
        received_at=date.today(),
    )
    db_session.add(batch)

    order = Order(
        item_id=item.id,
        mart_id=mart.id,
        order_date=date.today(),
        quantity_ordered=50.0,
        quantity_dispatched=0.0,
        status="Pending",
        unit="kg",
    )
    db_session.add(order)
    db_session.commit()

    return item, mart, batch, order


def test_dispatch_atomicity_rolls_back_on_ledger_failure(db_session, monkeypatch):
    item, _, batch, order = _seed_dispatch_basics(db_session)
    original_batch_qty = Decimal(str(batch.quantity))
    original_dispatched = Decimal(str(order.quantity_dispatched or 0))
    original_status = order.status

    def _fail_inventory_txn(*args, **kwargs):
        raise AppException("Forced ledger failure", status_code=500)

    monkeypatch.setattr(
        "app.services.dispatch_entry.create_inventory_txn", _fail_inventory_txn
    )

    payload = DispatchEntryCreate(
        item_id=item.id,
        batch_id=batch.id,
        mart_name="Atomic Mart",
        dispatch_date=date.today(),
        quantity=10.0,
        unit="kg",
        order_id=order.id,
    )

    with pytest.raises(AppException):
        create_dispatch_entry(db_session, payload, created_by="tester")

    db_batch = db_session.get(Batch, batch.id)
    db_order = db_session.get(Order, order.id)
    dispatch_count = db_session.query(InventoryTxn).filter_by(txn_type="OUT").count()
    # DispatchEntry row should not persist because commit is never reached.
    from app.db.models.dispatch_entry import DispatchEntry

    assert db_session.query(DispatchEntry).count() == 0
    assert Decimal(str(db_batch.quantity)) == original_batch_qty
    assert Decimal(str(db_order.quantity_dispatched or 0)) == original_dispatched
    assert db_order.status == original_status
    assert dispatch_count == 0


def test_mart_bill_upload_atomicity_rolls_back_on_mid_failure(db_session, monkeypatch):
    mart = Mart(name="Atomic Bill Mart", company_name="ABM Pvt")
    db_session.add(mart)
    db_session.commit()

    df = pd.DataFrame(
        [
            {
                "HSN_CODE": "1001",
                "ITEM_CODE": "ITM-1",
                "Item": "Atomic Item",
                "Quantity": 2.0,
                "UOM": "kg",
                "Price": 10.0,
                "Total": 20.0,
            }
        ]
    )

    def _fake_process_pdf(_):
        return df, date.today(), mart.name

    async def _fake_storage_save(_bytes, _filename):
        return None

    def _fail_bulk_save(_items):
        raise RuntimeError("Forced bulk_save failure")

    monkeypatch.setattr("app.services.mart_bill.process_pdf", _fake_process_pdf)
    monkeypatch.setattr("app.services.mart_bill.storage.save", _fake_storage_save)
    monkeypatch.setattr(db_session, "bulk_save_objects", _fail_bulk_save)

    file_obj = UploadFile(filename="atomic.pdf", file=BytesIO(b"%PDF-1.4\n"))

    with pytest.raises(AppException):
        asyncio.run(
            save_and_process_mart_bill(file_obj, db_session, created_by="tester")
        )

    assert db_session.query(MartBill).count() == 0
    assert db_session.query(MartBillItem).count() == 0


def test_reconciliation_resolve_atomicity_rolls_back_on_event_failure(
    db_session, monkeypatch
):
    uom = UOM(code="UNT", description="Unit")
    db_session.add(uom)
    db_session.flush()

    item = Item(
        name="Atomic Reconciliation Item",
        default_uom_id=uom.id,
        item_code="ARI-1",
    )
    db_session.add(item)
    db_session.flush()

    batch = Batch(item_id=item.id, quantity=Decimal("100.000"), unit="UNT")
    db_session.add(batch)
    db_session.commit()

    db_session.add(
        InventoryTxn(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=Decimal("110.000"),
            raw_unit="UNT",
            base_qty=Decimal("110.000"),
            base_unit="UNT",
        )
    )
    db_session.commit()

    record = create_drift_record(db_session, batch.id)
    assert record is not None
    assert record.status == DriftStatus.OPEN

    def _fail_domain_event(*args, **kwargs):
        raise RuntimeError("Forced event construction failure")

    monkeypatch.setattr("app.services.reconciliation.DomainEvent", _fail_domain_event)

    with pytest.raises(RuntimeError):
        resolve_drift(
            db_session,
            record_id=record.id,
            adjustment_qty=Decimal("-10.000"),
            user_id=1,
            apply_to_batch=False,
        )

    db_record = db_session.get(ReconciliationRecord, record.id)
    assert db_record.status == DriftStatus.OPEN
    assert db_record.resolution_txn_id is None

    adjust_count = (
        db_session.query(InventoryTxn)
        .filter(
            InventoryTxn.batch_id == batch.id,
            InventoryTxn.txn_type == "ADJUST",
            InventoryTxn.ref_type == "reconciliation_record",
            InventoryTxn.ref_id == record.id,
        )
        .count()
    )
    assert adjust_count == 0
