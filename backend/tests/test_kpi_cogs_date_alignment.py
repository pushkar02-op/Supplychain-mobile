from datetime import date, datetime
from decimal import Decimal

from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.order import Order
from app.db.models.stock_entry import StockEntry
from app.db.models.uom import UOM
from app.db.models.warehouse import Warehouse
from app.services.kpi import get_financial_kpi


def _ensure_warehouse(db_session, code: str, name: str) -> Warehouse:
    existing = db_session.query(Warehouse).filter(Warehouse.code == code).first()
    if existing:
        return existing
    warehouse = Warehouse(name=name, code=code, is_active=True)
    db_session.add(warehouse)
    db_session.commit()
    db_session.refresh(warehouse)
    return warehouse


def test_cogs_uses_dispatch_business_date_not_inventory_txn_created_at(db_session):
    warehouse = _ensure_warehouse(db_session, "MAIN", "Main Warehouse")

    uom = UOM(code="kg", description="Kilogram")
    item = Item(name="COGS Date Item", default_uom=uom)
    mart = Mart(name="COGS Date Mart", company_name="COGS Co")
    db_session.add_all([uom, item, mart])
    db_session.flush()

    order = Order(
        item_id=item.id,
        mart_id=mart.id,
        warehouse_id=warehouse.id,
        order_date=date(2026, 2, 1),
        quantity_ordered=Decimal("10.000"),
        quantity_dispatched=Decimal("5.000"),
        status="Partially Completed",
        unit="kg",
    )
    db_session.add(order)
    db_session.flush()

    batch = Batch(
        item_id=item.id,
        warehouse_id=warehouse.id,
        quantity=Decimal("20.000"),
        unit="kg",
        received_at=date(2026, 2, 1),
    )
    db_session.add(batch)
    db_session.flush()

    stock = StockEntry(
        item_id=item.id,
        batch_id=batch.id,
        warehouse_id=warehouse.id,
        received_date=date(2026, 2, 1),
        source="seed",
        price_per_unit=Decimal("10.000000"),
        total_cost=Decimal("200.000000"),
        quantity=Decimal("20.000"),
        unit="kg",
        is_active=True,
    )
    db_session.add(stock)
    db_session.flush()

    dispatch_in_range = DispatchEntry(
        batch_id=batch.id,
        item_id=item.id,
        warehouse_id=warehouse.id,
        dispatch_date=date(2026, 2, 3),
        mart_id=mart.id,
        quantity=Decimal("5.000"),
        unit="kg",
        order_id=order.id,
    )
    db_session.add(dispatch_in_range)
    db_session.flush()

    txn_for_in_range_dispatch = InventoryTxn(
        item_id=item.id,
        batch_id=batch.id,
        warehouse_id=warehouse.id,
        txn_type="OUT",
        raw_qty=Decimal("5.000"),
        raw_unit="kg",
        base_qty=Decimal("5.000"),
        base_unit="kg",
        ref_type="dispatch_entry",
        ref_id=dispatch_in_range.id,
        created_at=datetime(2026, 3, 10, 9, 0, 0),  # outside KPI window
        remarks="delayed posting",
    )
    db_session.add(txn_for_in_range_dispatch)

    dispatch_out_of_range = DispatchEntry(
        batch_id=batch.id,
        item_id=item.id,
        warehouse_id=warehouse.id,
        dispatch_date=date(2026, 3, 8),
        mart_id=mart.id,
        quantity=Decimal("4.000"),
        unit="kg",
        order_id=order.id,
    )
    db_session.add(dispatch_out_of_range)
    db_session.flush()

    txn_for_out_of_range_dispatch = InventoryTxn(
        item_id=item.id,
        batch_id=batch.id,
        warehouse_id=warehouse.id,
        txn_type="OUT",
        raw_qty=Decimal("4.000"),
        raw_unit="kg",
        base_qty=Decimal("4.000"),
        base_unit="kg",
        ref_type="dispatch_entry",
        ref_id=dispatch_out_of_range.id,
        created_at=datetime(2026, 2, 3, 10, 0, 0),  # inside KPI window
        remarks="early posting",
    )
    db_session.add(txn_for_out_of_range_dispatch)

    bill = MartBill(
        mart_id=mart.id,
        warehouse_id=warehouse.id,
        invoice_date=date(2026, 2, 3),
        file_path="/tmp/cogs-date.pdf",
        file_hash="cogs-date-hash",
        total_amount=Decimal("500.000000"),
        status="VERIFIED",
    )
    db_session.add(bill)
    db_session.commit()

    in_window = get_financial_kpi(
        db=db_session,
        warehouse_id=warehouse.id,
        start_date=date(2026, 2, 1),
        end_date=date(2026, 2, 28),
    )
    assert in_window["cogs"] == Decimal("50.000000")

    out_window = get_financial_kpi(
        db=db_session,
        warehouse_id=warehouse.id,
        start_date=date(2026, 3, 1),
        end_date=date(2026, 3, 31),
    )
    assert out_window["cogs"] == Decimal("40.000000")

    excluding_both_dispatch_dates = get_financial_kpi(
        db=db_session,
        warehouse_id=warehouse.id,
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
    )
    assert excluding_both_dispatch_dates["cogs"] == Decimal("0.000000")
