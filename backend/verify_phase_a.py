import os
import sys
from datetime import date, datetime

from sqlalchemy import func, select, text

from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.dispatch_entry import BatchDispatchInput, DispatchEntryMultiCreate
from app.db.session import SessionLocal
from app.services.dispatch_entry import (
    create_dispatch_from_order,
    delete_dispatch_entry,
)


def verify():
    db = SessionLocal()
    try:
        print("--- Phase A Verification Start (Native SQL Setup) ---")

        # 1. Setup Test Data using raw SQL to bypass ORM mixin issues
        # Clean existing test data
        db.execute(
            text(
                "DELETE FROM inventory_txn WHERE remarks LIKE '%Verification%' OR remarks LIKE '%test%'"
            )
        )
        db.execute(
            text("DELETE FROM dispatch_entry WHERE remarks = 'Multi-batch test'")
        )
        db.execute(
            text(
                "DELETE FROM \"order\" WHERE status = 'Pending' AND quantity_ordered = 150.0"
            )
        )
        db.execute(
            text(
                "DELETE FROM batch WHERE item_id IN (SELECT id FROM item WHERE name = 'Test Item Phase A')"
            )
        )
        db.execute(
            text(
                "DELETE FROM item_conversion_map WHERE item_id IN (SELECT id FROM item WHERE name = 'Test Item Phase A')"
            )
        )
        db.execute(text("DELETE FROM item WHERE name = 'Test Item Phase A'"))
        db.execute(text("DELETE FROM mart WHERE name = 'Test Mart'"))
        db.commit()

        # Insert UOM if missing
        db.execute(
            text(
                "INSERT INTO uom (code, description, created_at, updated_at, created_by) VALUES ('KG', 'Kilogram', now(), now(), 'verifier') ON CONFLICT (code) DO NOTHING"
            )
        )

        # Insert Mart
        mart_id = db.execute(
            text(
                "INSERT INTO mart (name, company_name, created_at, updated_at, created_by) VALUES ('Test Mart', 'Test Corp', now(), now(), 'verifier') RETURNING id"
            )
        ).scalar()

        # Insert Item
        item_id = db.execute(
            text(
                "INSERT INTO item (name, default_uom_id, created_at, updated_at, created_by) VALUES ('Test Item Phase A', (SELECT id FROM uom WHERE code='KG'), now(), now(), 'verifier') RETURNING id"
            )
        ).scalar()

        # Insert Batches
        b1_id = db.execute(
            text(
                "INSERT INTO batch (item_id, quantity, unit, received_at, created_at, updated_at, created_by) VALUES (:item_id, 100.0, 'KG', now(), now(), now(), 'verifier') RETURNING id"
            ),
            {"item_id": item_id},
        ).scalar()
        b2_id = db.execute(
            text(
                "INSERT INTO batch (item_id, quantity, unit, received_at, created_at, updated_at, created_by) VALUES (:item_id, 100.0, 'KG', now(), now(), now(), 'verifier') RETURNING id"
            ),
            {"item_id": item_id},
        ).scalar()
        b3_id = db.execute(
            text(
                "INSERT INTO batch (item_id, quantity, unit, received_at, created_at, updated_at, created_by) VALUES (:item_id, 100.0, 'KG', now(), now(), now(), 'verifier') RETURNING id"
            ),
            {"item_id": item_id},
        ).scalar()

        # Insert Order
        db.execute(
            text(
                "INSERT INTO \"order\" (item_id, mart_id, quantity_ordered, quantity_dispatched, order_date, status, unit, created_at, updated_at, created_by) VALUES (:item_id, :mart_id, 150.0, 0, now(), 'Pending', 'KG', now(), now(), 'verifier')"
            ),
            {"item_id": item_id, "mart_id": mart_id},
        )

        # Insert Conversion Map (Self)
        db.execute(
            text(
                "INSERT INTO item_conversion_map (item_id, source_unit, target_unit, conversion_factor, created_at, updated_at, created_by) VALUES (:item_id, 'KG', 'KG', 1.0, now(), now(), 'verifier')"
            ),
            {"item_id": item_id},
        )

        db.commit()
        print(
            f"Test Data Initialized: Item {item_id}, Mart {mart_id}, Batches [{b1_id}, {b2_id}, {b3_id}]"
        )

        # 2. Test Multi-Batch Ledgering
        payload = DispatchEntryMultiCreate(
            item_id=item_id,
            mart_name="Test Mart",
            dispatch_date=date.today(),
            unit="KG",
            batches=[
                BatchDispatchInput(batch_id=b1_id, quantity=50.0),
                BatchDispatchInput(batch_id=b2_id, quantity=50.0),
                BatchDispatchInput(batch_id=b3_id, quantity=50.0),
            ],
            remarks="Multi-batch test",
        )

        print("Executing create_dispatch_from_order...")
        results = create_dispatch_from_order(db, payload, created_by="verifier")

        # Assertions for Step 2
        txn_count = db.scalar(
            select(func.count(InventoryTxn.id)).where(
                InventoryTxn.item_id == item_id, InventoryTxn.txn_type == "OUT"
            )
        )
        print(f"Ledger entries created: {txn_count}")
        assert txn_count == 3, f"Expected 3 ledger entries, found {txn_count}"

        for bid in [b1_id, b2_id, b3_id]:
            db.expire_all()
            qty = db.execute(
                text("SELECT quantity FROM batch WHERE id = :id"), {"id": bid}
            ).scalar()
            print(f"Batch {bid} quantity: {qty}")
            assert qty == 50.0, f"Batch {bid} quantity mismatch"

        # 3. Test Stock Restoration on Delete
        dispatch_to_delete = results[0]
        dispatch_id = dispatch_to_delete.id
        batch_id = dispatch_to_delete.batch_id
        print(f"Deleting dispatch {dispatch_id} for batch {batch_id}...")

        success = delete_dispatch_entry(db, dispatch_id)
        assert success is True, "Delete operation failed"

        # Assertions for Step 3
        qty_restored = db.execute(
            text("SELECT quantity FROM batch WHERE id = :id"), {"id": batch_id}
        ).scalar()
        print(f"Restored batch {batch_id} quantity: {qty_restored}")
        assert qty_restored == 100.0, (
            f"Stock not restored. Expected 100.0, found {qty_restored}"
        )

        # Use simple select for reversal txn
        reversal_count = db.execute(
            text(
                "SELECT count(*) FROM inventory_txn WHERE batch_id = :bid AND txn_type = 'IN'"
            ),
            {"bid": batch_id},
        ).scalar()
        assert reversal_count >= 1, "Reversal ledger entry missing"
        print(f"Reversal txn(s) found: {reversal_count}")

        print("--- Verification Successful! ---")

    except Exception as e:
        print(f"--- Verification Failed: {e} ---")
        import traceback

        traceback.print_exc()
        db.rollback()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    verify()
