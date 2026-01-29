import logging
import os
import sys

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.db.models import UOM, Batch, Item, StockEntry
from app.db.session import SessionLocal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def audit_usage():
    db = SessionLocal()
    try:
        total_items = db.query(Item).count()

        # Items with Stock Entries
        items_with_stock = (
            db.query(Item.id)
            .join(StockEntry, Item.id == StockEntry.item_id)
            .distinct()
            .count()
        )

        # Items with Batches
        items_with_batches = (
            db.query(Item.id).join(Batch, Item.id == Batch.item_id).distinct().count()
        )

        # Items with Dispatch (Need to check DispatchEntry model, but assuming StockEntry/Batch/Dispatch logic)
        # Checking DispatchEntry if it exists
        # from app.db.models.dispatch_entry import DispatchEntry
        # items_with_dispatch = db.query(Item.id).join(DispatchEntry, Item.id == DispatchEntry.item_id).distinct().count()
        # For now, let's stick to Stock/Batch as primary "History" indicators.

        unused = (
            total_items - items_with_stock
        )  # Simplification, assuming StockEntry is the entry point

        print("\n=== ITEM USAGE STATISTICS ===")
        print(f"Total Items: {total_items}")
        print(
            f"Items with Stock History: {items_with_stock} ({(items_with_stock / total_items * 100) if total_items else 0:.1f}%)"
        )
        print(f"Items with Batches (Inventory): {items_with_batches}")
        print(f"Fully Unused Items: {unused}")
        print("=============================\n")

    finally:
        db.close()


def verify_delete_enforcement():
    db = SessionLocal()
    print("\n=== DELETE ENFORCEMENT VERIFICATION ===")
    try:
        # 1. Create Test Item
        uom = db.query(UOM).first()
        if not uom:
            print("No UOMs found, cannot run test.")
            return

        test_item = Item(
            name="AUDIT_TEST_DELETE_ME", default_uom_id=uom.id, created_by="AUDIT"
        )
        db.add(test_item)
        db.commit()
        db.refresh(test_item)
        print(f"[TEST] Created Item ID: {test_item.id}")

        # 2. Create Dependency (Stock Entry)
        # Need a Batch first? StockEntry links to Batch?
        # Checking StockEntry model: item_id, batch_id

        test_batch = Batch(
            item_id=test_item.id, quantity=10, unit=uom.code, created_by="AUDIT"
        )
        db.add(test_batch)
        db.commit()
        db.refresh(test_batch)

        test_stock = StockEntry(
            item_id=test_item.id,
            batch_id=test_batch.id,
            received_date="2026-01-01",
            price_per_unit=10,
            total_cost=100,
            quantity=10,
            unit=uom.code,
            created_by="AUDIT",
        )
        db.add(test_stock)
        db.commit()
        print(f"[TEST] Created Dependency (StockEntry ID: {test_stock.id})")

        # 3. Attempt Delete
        print("[TEST] Attempting DELETE...")
        db.delete(test_item)
        db.commit()
        print(
            "[FAIL] Delete SUCCESS (Unexpected!) - Backend does not enforce constraint?"
        )

    except IntegrityError as e:
        print("[SUCCESS] Delete BLOCKED by Database.")
        print(f"Exception Type: {type(e).__name__}")
        print(f"Message: {e.orig}")
        db.rollback()

    except Exception as e:
        print(f"[ERROR] Unexpected Exception: {type(e).__name__}")
        print(str(e))
        db.rollback()

    finally:
        # Cleanup
        try:
            # We need to clean up strictly in order
            db.execute(
                text("DELETE FROM stock_entry WHERE item_id = :id"),
                {"id": test_item.id},
            )
            db.execute(
                text("DELETE FROM batch WHERE item_id = :id"), {"id": test_item.id}
            )
            db.execute(text("DELETE FROM item WHERE id = :id"), {"id": test_item.id})
            db.commit()
            print("[TEST] Cleanup Complete")
        except Exception as cleanup_err:
            print(f"[WARN] Cleanup failed: {cleanup_err}")
        db.close()
        print("=======================================\n")


if __name__ == "__main__":
    audit_usage()
    verify_delete_enforcement()
