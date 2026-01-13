import os
import sys
from datetime import date

from sqlalchemy import text

# Add project root to path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.db.schemas.dispatch_entry import DispatchEntryCreate
from app.db.schemas.stock_entry import StockEntryCreate
from app.db.session import SessionLocal
from app.services.dispatch_entry import create_dispatch_entry
from app.services.reconciliation import check_batch_drift
from app.services.stock_entry import create_stock_entry, delete_stock_entry


def verify():
    db = SessionLocal()
    try:
        print("--- Phase C Verification Start ---")

        # 0. Setup Test Item and Batch
        print("Cleaning up existing test data...")
        item_id_subquery = "(SELECT id FROM item WHERE name = 'Phase C Item')"

        # Delete in order of constraints
        db.execute(
            text(f"DELETE FROM dispatch_entry WHERE item_id IN {item_id_subquery}")
        )
        db.execute(
            text(
                f"DELETE FROM rejection_entries WHERE batch_id IN (SELECT id FROM batch WHERE item_id IN {item_id_subquery})"
            )
        )
        db.execute(
            text(f"DELETE FROM inventory_txn WHERE item_id IN {item_id_subquery}")
        )
        db.execute(text(f"DELETE FROM stockentry WHERE item_id IN {item_id_subquery}"))
        db.execute(text(f"DELETE FROM batch WHERE item_id IN {item_id_subquery}"))
        db.execute(
            text(f"DELETE FROM item_alias WHERE master_item_id IN {item_id_subquery}")
        )
        db.execute(
            text(f"DELETE FROM item_conversion_map WHERE item_id IN {item_id_subquery}")
        )
        db.execute(text("DELETE FROM item WHERE name = 'Phase C Item'"))
        db.commit()

        # Ensure dependencies
        db.execute(
            text(
                "INSERT INTO uom (code, description, created_at, updated_at, created_by) VALUES ('L', 'Litre', now(), now(), 'verifier') ON CONFLICT (code) DO NOTHING"
            )
        )

        # Mart may not have unique constraint, check existence manually
        mart_exists = db.execute(
            text("SELECT id FROM mart WHERE name = 'Test Mart' LIMIT 1")
        ).scalar()
        if not mart_exists:
            db.execute(
                text(
                    "INSERT INTO mart (name, company_name, created_at, updated_at, created_by) VALUES ('Test Mart', 'Test Company', now(), now(), 'verifier')"
                )
            )

        db.commit()

        item_id = db.execute(
            text(
                "INSERT INTO item (name, default_uom_id, created_at, updated_at, created_by) "
                "VALUES ('Phase C Item', (SELECT id FROM uom WHERE code='L'), now(), now(), 'verifier') "
                "RETURNING id"
            )
        ).scalar()
        db.commit()

        print(f"Test Item {item_id} created.")

        # 1. Create Stock Entry
        print("1. Creating Stock Entry (100 L)...")
        stock_payload = StockEntryCreate(
            item_id=item_id,
            quantity=100.0,
            unit="L",
            received_date=date.today(),
            price_per_unit=1.0,
            total_cost=100.0,
            source="Phase C Setup",
        )
        se = create_stock_entry(db, stock_payload, created_by=1)
        batch_id = se.batch_id

        # 2. Test Guardrail: Block deletion if dispatch exists
        print("2. Testing Deletion Guardrail (Dispatch)...")
        dispatch_payload = DispatchEntryCreate(
            item_id=item_id,
            batch_id=batch_id,
            quantity=10,
            unit="L",
            dispatch_date=date.today(),
            mart_name="Test Mart",
            remarks="Downstream dispatch",
        )
        create_dispatch_entry(db, dispatch_payload, created_by=1)

        try:
            delete_stock_entry(db, se.id)
            print("FAIL: StockEntry deletion NOT blocked by dispatch!")
            sys.exit(1)
        except Exception as e:
            print(f"OK: Deletion blocked as expected: {e}")

        # 3. Test Drift Detection (Manual corruption for testing)
        print("3. Testing Drift Detection...")
        db.execute(
            text("UPDATE batch SET quantity = 105 WHERE id = :bid"), {"bid": batch_id}
        )
        db.commit()

        metrics = check_batch_drift(db, batch_id)
        print(
            f"Drift Metrics: batch={metrics['batch_qty_base']}, ledger={metrics['ledger_qty']}, drift={metrics['drift']}, status={metrics['status']}"
        )
        assert metrics["status"] == "drifted"
        assert metrics["is_drifted"] is True
        print("OK: Real drift (> tolerance) detected.")

        # 4. Test Tolerance Threshold
        print("4. Testing Drift Tolerance (Noise Protection)...")
        db.execute(
            text("UPDATE batch SET quantity = 90 WHERE id = :bid"), {"bid": batch_id}
        )  # Reset
        db.commit()

        print("Testing tolerance with conversion noise...")
        db.execute(
            text(
                "INSERT INTO uom (code, description, created_at, updated_at, created_by) VALUES ('PKT', 'Packet', now(), now(), 'verifier') ON CONFLICT (code) DO NOTHING"
            )
        )
        db.execute(
            text(
                "INSERT INTO item_conversion_map (item_id, source_unit, target_unit, conversion_factor, created_at, updated_at, created_by) VALUES (:item_id, 'PKT', 'L', 2.00001, now(), now(), 'verifier')"
            ),
            {"item_id": item_id},
        )
        db.execute(
            text("UPDATE batch SET unit = 'PKT', quantity = 45 WHERE id = :bid"),
            {"bid": batch_id},
        )
        db.commit()

        metrics_noise = check_batch_drift(db, batch_id)
        print(
            f"Drift (with noise): drift={metrics_noise['drift']}, status={metrics_noise['status']}"
        )
        assert metrics_noise["status"] == "healthy"
        assert metrics_noise["is_drifted"] is False
        print("OK: Minor conversion noise ignored.")

        print("--- ALL VERIFICATIONS PASSED ---")

    except Exception as e:
        print(f"Verification FAILED: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    verify()
