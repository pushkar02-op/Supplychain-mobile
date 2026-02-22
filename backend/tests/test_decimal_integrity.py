from datetime import date
from decimal import Decimal

from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.models.uom import UOM
from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.dispatch_entry import create_dispatch_entry
from app.services.inventory_txn import create_inventory_txn


def _seed_item_mart_batch(db_session):
    uom = UOM(code="kg", description="Kilogram")
    db_session.add(uom)
    db_session.flush()

    item = Item(name="Decimal Item", default_uom_id=uom.id, item_code="DEC-1")
    mart = Mart(name="Decimal Mart", company_name="Decimal Co")
    db_session.add_all([item, mart])
    db_session.flush()

    batch = Batch(
        item_id=item.id,
        quantity=Decimal("5.000"),
        unit="kg",
        received_at=date.today(),
    )
    db_session.add(batch)
    db_session.commit()
    db_session.refresh(item)
    db_session.refresh(mart)
    db_session.refresh(batch)
    return item, mart, batch


def test_post_order_with_decimal_quantity_stored_exactly(client, db_session):
    item, mart, _ = _seed_item_mart_batch(db_session)

    response = client.post(
        "/v1/orders/",
        json={
            "item_id": item.id,
            "unit": "kg",
            "order_date": str(date.today()),
            "quantity_ordered": 10.125,
            "mart_name": mart.name,
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert isinstance(payload["quantity_ordered"], (int, float))
    assert not isinstance(payload["quantity_ordered"], str)
    assert payload["quantity_ordered"] == 10.125

    db_order = db_session.query(Order).filter(Order.id == payload["id"]).first()
    assert db_order is not None
    assert Decimal(str(db_order.quantity_ordered)) == Decimal("10.125")


def test_dispatch_fractional_quantity_has_no_precision_drift(db_session):
    item, mart, batch = _seed_item_mart_batch(db_session)

    order = Order(
        item_id=item.id,
        mart_id=mart.id,
        order_date=date.today(),
        quantity_ordered=5.0,
        quantity_dispatched=0.0,
        status="Pending",
        unit="kg",
    )
    db_session.add(order)
    db_session.commit()

    dispatch = create_dispatch_entry(
        db_session,
        DispatchEntryCreate(
            item_id=item.id,
            batch_id=batch.id,
            mart_name=mart.name,
            dispatch_date=date.today(),
            quantity=Decimal("1.125"),
            unit="kg",
            order_id=order.id,
        ),
        created_by="tester",
    )

    db_session.refresh(batch)
    assert Decimal(str(dispatch.quantity)) == Decimal("1.125")
    assert Decimal(str(batch.quantity)) == Decimal("3.875")


def test_decimal_json_response_is_numeric_not_string(client, db_session):
    item, mart, batch = _seed_item_mart_batch(db_session)

    response = client.post(
        "/v1/dispatch-entries/",
        json={
            "item_id": item.id,
            "batch_id": batch.id,
            "mart_name": mart.name,
            "dispatch_date": str(date.today()),
            "quantity": 0.5,
            "unit": "kg",
            "remarks": "decimal-check",
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert isinstance(payload["quantity"], (int, float))
    assert not isinstance(payload["quantity"], str)


def test_decimal_summation_preserves_precision(db_session):
    item, _, batch = _seed_item_mart_batch(db_session)

    create_inventory_txn(
        db_session,
        InventoryTxnCreate(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="OUT",
            raw_qty=Decimal("0.333"),
            raw_unit="kg",
            base_qty=Decimal("0.333"),
            base_unit="kg",
            ref_type="decimal_test",
            ref_id=1,
        ),
    )
    create_inventory_txn(
        db_session,
        InventoryTxnCreate(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="OUT",
            raw_qty=Decimal("0.667"),
            raw_unit="kg",
            base_qty=Decimal("0.667"),
            base_unit="kg",
            ref_type="decimal_test",
            ref_id=2,
        ),
    )
    db_session.commit()

    txns = (
        db_session.query(InventoryTxn)
        .filter(
            InventoryTxn.item_id == item.id,
            InventoryTxn.ref_type == "decimal_test",
        )
        .order_by(InventoryTxn.id.asc())
        .all()
    )
    total = sum((Decimal(str(txn.base_qty)) for txn in txns), Decimal("0"))
    assert total == Decimal("1.000")
