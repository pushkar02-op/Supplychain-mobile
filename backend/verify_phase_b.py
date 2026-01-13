import sys
from datetime import date

from sqlalchemy import select, text

from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.session import SessionLocal
from app.services.rejection_entry import create_rejection_entry
from app.services.stock_entry import create_stock_entry, delete_stock_entry


def verify():
    db = SessionLocal()
    try:
        print("--- Phase B Verification Start ---")

        # 1. Setup Test Data
        # Clean existing test data
        db.execute(
            text(
                "DELETE FROM inventory_txn WHERE remarks LIKE '%Verification%' OR remarks LIKE '%Phase B%'"
            )
        )
        db.execute(
            text("DELETE FROM rejection_entries WHERE remarks = 'Phase B Rejection'")
        )
        db.execute(text("DELETE FROM stockentry WHERE remarks = 'Phase B Stock'"))
        db.execute(
            text(
                "DELETE FROM batch WHERE item_id IN (SELECT id FROM item WHERE name = 'Phase B Item')"
            )
        )
        db.execute(
            text(
                "DELETE FROM item_alias WHERE item_id IN (SELECT id FROM item WHERE name = 'Phase B Item')"
            )
        )
        db.execute(
            text(
                "DELETE FROM item_conversion_map WHERE item_id IN (SELECT id FROM item WHERE name = 'Phase B Item')"
            )
        )
        db.execute(text("DELETE FROM item WHERE name = 'Phase B Item'"))
        db.commit()

        # Insert UOM and Item
        db.execute(
            text(
                "INSERT INTO uom (code, description, created_at, updated_at, created_by) VALUES ('L', 'Litre', now(), now(), 'verifier') ON CONFLICT (code) DO NOTHING"
            )
        )
        item_id = db.execute(
            text(
                "INSERT INTO item (name, default_uom_id, created_at, updated_at, created_by) VALUES ('Phase B Item', (SELECT id FROM uom WHERE code='L'), now(), now(), 'verifier') RETURNING id"
            )
        ).scalar()

        # Insert Conversion Map for PKT (1 PKT = 0.5 L)
        db.execute(
            text(
                "INSERT INTO uom (code, description, created_at, updated_at, created_by) VALUES ('PKT', 'Packet', now(), now(), 'verifier') ON CONFLICT (code) DO NOTHING"
            )
        )
        db.execute(
            text(
                "INSERT INTO item_conversion_map (item_id, source_unit, target_unit, conversion_factor, created_at, updated_at, created_by) VALUES (:item_id, 'PKT', 'L', 0.5, now(), now(), 'verifier')"
            ),
            {"item_id": item_id},
        )
        db.commit()

        print(f"Test Data Initialized: Item {item_id}")

        # 2. Test Stock Entry Create (Ledger + Batch Sync)
        print("Testing create_stock_entry...")
        stock_payload = StockEntryCreate(
            item_id=item_id,
            quantity=10.0,
            unit="PKT",
            received_date=date.today(),
            price_per_unit=100.0,
            total_cost=1000.0,
            remarks="Phase B Stock",
        )
        se = create_stock_entry(db, stock_payload, created_by=1)

        # Verify Batch
        batch = db.execute(
            text("SELECT id, quantity, unit FROM batch WHERE id = :bid"),
            {"bid": se.batch_id},
        ).fetchone()
        print(
            f"Batch created/updated: id={batch.id}, qty={batch.quantity}, unit={batch.unit}"
        )
        assert float(batch.quantity) == 10.0, (
            f"Expected 10.0 PKT in batch, found {batch.quantity}"
        )

        # Verify Ledger
        # 10 PKT = 5.0 L (base unit)
        txn = db.scalar(
            select(InventoryTxn).where(
                InventoryTxn.ref_id == se.id, InventoryTxn.ref_type == "stock_entry"
            )
        )
        print(
            f"Ledger entry: type={txn.txn_type}, raw_qty={txn.raw_qty}, base_qty={txn.base_qty}, base_unit={txn.base_unit}"
        )
        assert txn.txn_type == "IN"
        assert float(txn.raw_qty) == 10.0
        assert float(txn.base_qty) == 5.0
        assert txn.base_unit == "L"

        # 3. Test Rejection Entry (OUT ledger + Batch decrement)
        print("Testing create_rejection_entry...")
        rej_payload = RejectionEntryCreate(
            batch_id=batch.id,
            quantity=2.0,
            rejection_date=date.today(),
            reason="Damaged",
            remarks="Phase B Rejection",
        )
        rejection = create_rejection_entry(db, rej_payload, created_by="verifier")

        # Verify Batch
        new_batch_qty = db.execute(
            text("SELECT quantity FROM batch WHERE id = :bid"), {"bid": batch.id}
        ).scalar()
        print(f"Batch quantity after rejection: {new_batch_qty}")
        assert float(new_batch_qty) == 8.0, f"Expected 8.0 PKT, found {new_batch_qty}"

        # Verify Ledger
        # 2 PKT = 1.0 L (base unit)
        txn_rej = db.scalar(
            select(InventoryTxn).where(
                InventoryTxn.ref_id == rejection.id,
                InventoryTxn.ref_type == "rejection_entry",
            )
        )
        print(
            f"Rejection Ledger: type={txn_rej.txn_type}, base_qty={txn_rej.base_qty}, base_unit={txn_rej.base_unit}"
        )
        assert txn_rej.txn_type == "OUT"
        assert float(txn_rej.base_qty) == 1.0
        assert txn_rej.base_unit == "L"

        # 4. Test Stock Entry Delete (Reversal)
        print("Testing delete_stock_entry...")
        success = delete_stock_entry(db, se.id)
        assert success is True

        # Verify Batch
        # Started 10, rejected 2 -> 8. Deleted 10 IN -> 8 - 10 = -2.
        final_qty = db.execute(
            text("SELECT quantity FROM batch WHERE id = :bid"), {"bid": batch.id}
        ).scalar()
        print(f"Final batch quantity after delete: {final_qty}")
        assert float(final_qty) == -2.0

        # Verify reversal ledger
        txn_rev = db.scalar(
            select(InventoryTxn).where(
                InventoryTxn.ref_id == se.id,
                InventoryTxn.txn_type == "OUT",
                InventoryTxn.remarks == "Stock removed via delete",
            )
        )
        assert txn_rev is not None
        assert float(txn_rev.base_qty) == 5.0

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
