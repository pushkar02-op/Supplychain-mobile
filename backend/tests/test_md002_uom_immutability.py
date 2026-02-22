"""
Phase 4A: MDU-002 Default UOM Immutability Tests
Verifies that default_uom_id cannot be changed after inventory transactions exist.
"""

from datetime import datetime
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.exceptions import AppException
from app.db.base import Base
from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.models.uom import UOM
from app.db.schemas.item import ItemUpdate
from app.services.item import update_item


def get_session():
    """In-memory SQLite for isolation."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, checkfirst=True)
    Session = sessionmaker(bind=engine)
    return Session()


def test_block_uom_change_after_inventory():
    """
    Test 1: Block UOM Change After Inventory
    - Create Item
    - Create InventoryTxn (simulating stock entry)
    - Attempt to change default_uom_id
    - Expect 409 Conflict
    """
    db = get_session()

    # Setup UOMs
    uom_kg = UOM(code="kg", description="Kilogram")
    uom_lbs = UOM(code="lbs", description="Pounds")
    db.add_all([uom_kg, uom_lbs])
    db.flush()

    # Create Item with kg
    item = Item(name="TestItem", default_uom_id=uom_kg.id)
    db.add(item)
    db.flush()

    # Create Batch for the item
    batch = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("10.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch)
    db.flush()

    # Create InventoryTxn (simulating stock entry)
    txn = InventoryTxn(
        item_id=item.id,
        batch_id=batch.id,
        txn_type="IN",
        raw_qty=Decimal("10.0"),
        raw_unit="kg",
        base_qty=Decimal("10.0"),
        base_unit="kg",
        ref_type="stock_entry",
        ref_id=1,
    )
    db.add(txn)
    db.commit()

    # Attempt to change UOM via default_unit string
    update_payload = ItemUpdate(default_unit="lbs")

    try:
        update_item(db, item.id, update_payload, updated_by=1)
        raise AssertionError("Expected AppException was not raised!")
    except AppException as e:
        assert e.status_code == 409
        assert "MDU-002" in str(e.extra.get("rule_id", ""))
        print("PASS: Block UOM Change After Inventory")


def test_allow_uom_change_before_inventory():
    """
    Test 2: Allow UOM Change Before Inventory
    - Create Item
    - No inventory transactions
    - Change default_uom_id
    - Expect success
    """
    db = get_session()

    uom_kg = UOM(code="kg", description="Kilogram")
    uom_lbs = UOM(code="lbs", description="Pounds")
    db.add_all([uom_kg, uom_lbs])
    db.flush()

    item = Item(name="TestItem2", default_uom_id=uom_kg.id)
    db.add(item)
    db.commit()

    # No inventory — should allow change
    update_payload = ItemUpdate(default_unit="lbs")
    result = update_item(db, item.id, update_payload, updated_by=1)

    assert result is not None
    # Verify the update took effect
    updated_item = db.get(Item, item.id)
    assert updated_item.default_uom_id == uom_lbs.id
    print("PASS: Allow UOM Change Before Inventory")


def test_allow_non_uom_updates_after_inventory():
    """
    Test 3: Allow Non-UOM Updates After Inventory
    - Item with inventory
    - Update name/description
    - Expect success
    """
    db = get_session()

    uom_kg = UOM(code="kg", description="Kilogram")
    db.add(uom_kg)
    db.flush()

    item = Item(name="TestItem3", default_uom_id=uom_kg.id)
    db.add(item)
    db.flush()

    batch = Batch(
        item_id=item.id,
        unit="kg",
        quantity=Decimal("5.0"),
        received_at=datetime.utcnow().date(),
    )
    db.add(batch)
    db.flush()

    txn = InventoryTxn(
        item_id=item.id,
        batch_id=batch.id,
        txn_type="IN",
        raw_qty=Decimal("5.0"),
        raw_unit="kg",
        base_qty=Decimal("5.0"),
        base_unit="kg",
        ref_type="stock_entry",
        ref_id=1,
    )
    db.add(txn)
    db.commit()

    # Update name only (not UOM)
    update_payload = ItemUpdate(name="RenamedItem3")
    result = update_item(db, item.id, update_payload, updated_by=1)

    assert result is not None
    updated_item = db.get(Item, item.id)
    assert updated_item.name == "RenamedItem3"
    print("PASS: Allow Non-UOM Updates After Inventory")


if __name__ == "__main__":
    try:
        test_block_uom_change_after_inventory()
        test_allow_uom_change_before_inventory()
        test_allow_non_uom_updates_after_inventory()
        print("\n=== ALL MDU-002 TESTS PASSED ===")
    except Exception:
        import traceback

        traceback.print_exc()
