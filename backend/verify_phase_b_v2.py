import sys
import traceback
from datetime import date

from sqlalchemy import select, text

from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.session import SessionLocal
from app.services.rejection_entry import create_rejection_entry
from app.services.stock_entry import create_stock_entry, delete_stock_entry


def run_step(db, description, func):
    print(f"--- Step: {description} ---")
    try:
        res = func(db)
        print("Result: OK")
        return res
    except Exception as e:
        print(f"Result: FAIL -> {e}")
        traceback.print_exc()
        db.rollback()
        raise


def verify():
    db = SessionLocal()
    try:
        # 1. Inspect Tables
        print("--- Table Inspection ---")
        tables = db.execute(
            text(
                "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
            )
        ).fetchall()
        table_list = [t[0] for t in tables]
        print(f"Tables: {table_list}")

        # 2. Cleanup
        def cleanup(db):
            sqls = [
                "DELETE FROM inventory_txn WHERE remarks LIKE '%Phase B%'",
                "DELETE FROM rejection_entries WHERE reason = 'Phase B Rejection'",
                "DELETE FROM stockentry WHERE source = 'Phase B Stock'",
                "DELETE FROM batch WHERE item_id IN (SELECT id FROM item WHERE name = 'Phase B Item')",
                "DELETE FROM item_alias WHERE item_id IN (SELECT id FROM item WHERE name = 'Phase B Item')",
                "DELETE FROM item_conversion_map WHERE item_id IN (SELECT id FROM item WHERE name = 'Phase B Item')",
                "DELETE FROM item WHERE name = 'Phase B Item'",
            ]
            for sql in sqls:
                tname = sql.split()[2]
                if tname in table_list:
                    db.execute(text(sql))
                    print(f"Cleaned {tname}")
                else:
                    print(f"Skipping {tname} (not found)")
            db.commit()

        run_step(db, "Cleanup", cleanup)

        # 3. Setup
        def setup(db):
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
            return item_id

        item_id = run_step(db, "Setup", setup)

        # 4. Create Stock Entry
        def test_create_se(db):
            payload = StockEntryCreate(
                item_id=item_id,
                quantity=10.0,
                unit="PKT",
                received_date=date.today(),
                price_per_unit=100.0,
                total_cost=1000.0,
                source="Phase B Stock",
            )
            se = create_stock_entry(db, payload, created_by=1)
            # Verify Batch
            batch = db.execute(
                text("SELECT quantity FROM batch WHERE id = :bid"), {"bid": se.batch_id}
            ).fetchone()
            assert float(batch[0]) == 10.0
            # Verify Ledger
            txn = db.scalar(
                select(InventoryTxn).where(
                    InventoryTxn.ref_id == se.id, InventoryTxn.ref_type == "stock_entry"
                )
            )
            assert float(txn.base_qty) == 5.0
            print(f"Ledger Base Qty: {txn.base_qty} {txn.base_unit}")
            return se

        se = run_step(db, "Test Create Stock Entry", test_create_se)

        # 5. Create Rejection
        def test_create_rej(db):
            payload = RejectionEntryCreate(
                batch_id=se.batch_id,
                quantity=2.0,
                rejection_date=date.today(),
                reason="Phase B Rejection",
                rejected_by="verifier",
            )
            rejection = create_rejection_entry(db, payload, created_by="verifier")
            # Verify Batch
            batch_qty = db.execute(
                text("SELECT quantity FROM batch WHERE id = :bid"), {"bid": se.batch_id}
            ).scalar()
            assert float(batch_qty) == 8.0
            # Verify Ledger
            txn = db.scalar(
                select(InventoryTxn).where(
                    InventoryTxn.ref_id == rejection.id,
                    InventoryTxn.ref_type == "rejection_entry",
                )
            )
            assert float(txn.base_qty) == 1.0
            print(f"Rejection Ledger Base Qty: {txn.base_qty} {txn.base_unit}")
            return rejection

        run_step(db, "Test Create Rejection", test_create_rej)

        # 6. Delete Stock Entry
        def test_delete_se(db):
            success = delete_stock_entry(db, se.id)
            assert success is True
            # Verify Batch
            final_qty = db.execute(
                text("SELECT quantity FROM batch WHERE id = :bid"), {"bid": se.batch_id}
            ).scalar()
            assert float(final_qty) == -2.0
            # Verify Reversal Ledger
            txn_rev = db.scalar(
                select(InventoryTxn).where(
                    InventoryTxn.ref_id == se.id,
                    InventoryTxn.txn_type == "OUT",
                    InventoryTxn.remarks == "Stock removed via delete",
                )
            )
            assert float(txn_rev.base_qty) == 5.0
            return True

        run_step(db, "Test Delete Stock Entry", test_delete_se)

        print("--- ALL VERIFICATIONS PASSED ---")

    except Exception as e:
        print(f"Verification stopped at fatal error: {e}")
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    verify()
