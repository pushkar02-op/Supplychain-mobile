import logging
import sys

# Ensure we can import app modules
# Container working dir is /app. 'app' package is at /app/app.
# So "from app.db..." should work if we run as module or set path.
sys.path.append("/app")

from app.db.models import UOM, Batch, Item, StockEntry
from app.db.session import SessionLocal
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

logging.basicConfig(level=logging.WARN)  # Less noise
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

        unused = total_items - items_with_stock

        logger.warning("=== ITEM USAGE STATISTICS ===")
        logger.warning("Total Items: %s", total_items)
        logger.warning(
            "Items with Stock History: %s (%.1f%%)",
            items_with_stock,
            (items_with_stock / total_items * 100) if total_items else 0,
        )
        logger.warning("Items with Batches (Inventory): %s", items_with_batches)
        logger.warning("Fully Unused Items: %s", unused)
        logger.warning("=============================")

    finally:
        db.close()


def verify_delete_enforcement():
    db = SessionLocal()
    logger.warning("=== DELETE ENFORCEMENT VERIFICATION ===")
    test_item = None
    try:
        # 1. Create Test Item
        uom = db.query(UOM).first()
        if not uom:
            logger.warning("No UOMs found, cannot run test.")
            return

        test_item = Item(
            name="AUDIT_TEST_DELETE_ME", default_uom_id=uom.id, created_by="AUDIT"
        )
        db.add(test_item)
        db.commit()
        db.refresh(test_item)
        logger.warning("[TEST] Created Item ID: %s", test_item.id)

        # 2. Create Dependency (Stock Entry)
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
        logger.warning("[TEST] Created Dependency (StockEntry ID: %s)", test_stock.id)

        # 3. Attempt Delete
        logger.warning("[TEST] Attempting DELETE...")
        db.delete(test_item)
        db.commit()
        logger.warning(
            "[FAIL] Delete SUCCESS (Unexpected!) - Backend does not enforce constraint?"
        )

    except IntegrityError as e:
        logger.warning("[SUCCESS] Delete BLOCKED by Database.")
        logger.warning("Exception Type: %s", type(e).__name__)
        logger.warning("Message: %s", e.orig)
        db.rollback()

    except Exception as e:
        logger.error("[ERROR] Unexpected Exception: %s", type(e).__name__)
        logger.error("%s", e)
        db.rollback()

    finally:
        # Cleanup
        if test_item:
            try:
                # We need to clean up strictly in order
                db.execute(
                    text("DELETE FROM stock_entry WHERE item_id = :id"),
                    {"id": test_item.id},
                )
                db.execute(
                    text("DELETE FROM batch WHERE item_id = :id"), {"id": test_item.id}
                )
                db.execute(
                    text("DELETE FROM item WHERE id = :id"), {"id": test_item.id}
                )
                db.commit()
                logger.warning("[TEST] Cleanup Complete")
            except Exception as cleanup_err:
                logger.warning("[WARN] Cleanup failed: %s", cleanup_err)
        db.close()
        logger.warning("=======================================")


if __name__ == "__main__":
    audit_usage()
    verify_delete_enforcement()
