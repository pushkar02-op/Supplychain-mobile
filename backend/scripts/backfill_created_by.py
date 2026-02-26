"""
Backfill script for `created_by_id`.
Usage: python scripts/backfill_created_by.py [--dry-run]
"""

import argparse
import logging
import os
import sys
from urllib.parse import urlparse

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Dynamic path setup: Try to import 'app'. If fail, add parent/backend to path.
# Assuming script is in scripts/ and backend is in backend/ relative to project root
# OR script is in backend/scripts/ and app is in backend/app
# We want to add the folder containing 'app' package to sys.path
# On Host: scripts/ is sibling to backend/. backend/ contains app/.
# So we need to add 'backend' folder to path.
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
backend_path = os.path.join(project_root, "backend")
if os.path.exists(backend_path):
    sys.path.append(backend_path)
else:
    # Maybe we are in backend root?
    sys.path.append(project_root)

try:
    from app.db.models.batch import Batch
    from app.db.models.dispatch_entry import DispatchEntry
    from app.db.models.invoice import Invoice
    from app.db.models.invoice_item import InvoiceItem
    from app.db.models.item import Item
    from app.db.models.item_alias import ItemAlias
    from app.db.models.item_conversion_map import ItemConversionMap
    from app.db.models.mart import Mart
    from app.db.models.order import Order
    from app.db.models.rejection_entry import RejectionEntry
    from app.db.models.stock_entry import StockEntry
    from app.db.models.uom import UOM
    from app.db.models.user import User
    from app.db.session import SessionLocal, settings
except ImportError as e:
    logger.error(f"Failed to import app modules: {e}")
    logger.error("Ensure you are running this script with access to the 'app' package.")
    sys.exit(1)
    sys.exit(1)

MODELS_TO_BACKFILL = [
    User,
    Batch,
    StockEntry,
    Order,
    Invoice,
    InvoiceItem,
    DispatchEntry,
    RejectionEntry,
    Item,
    ItemAlias,
    Mart,
    UOM,
    ItemConversionMap,
]


def print_banner(dry_run: bool):
    db_url = settings.DATABASE_URL
    # Mask password
    try:
        parsed = urlparse(db_url)
        masked_url = f"{parsed.scheme}://{parsed.username}:***@{parsed.hostname}:{parsed.port}/{parsed.path.lstrip('/')}"
        host = parsed.hostname
    except Exception:
        masked_url = "INVALID_URL_FORMAT"
        host = "UNKNOWN"

    print("=" * 60)
    print(" BACKFILL: Created_By_ID Population")
    print(f" Mode: {'DRY RUN (Read-Only)' if dry_run else 'LIVE EXECUTION'}")
    print(f" Database: {host} ({masked_url})")
    print("=" * 60)

    if host not in ["db", "localhost", "127.0.0.1"]:
        print("WARNING: You are connecting to a non-standard host!")
        if not dry_run:
            confirm = input("Are you sure? (type 'yes'): ")
            if confirm != "yes":
                print("Aborted.")
                sys.exit(1)


BATCH_SIZE = 500


def resolve_user_id(db: Session, created_by: str) -> int:
    """
    Resolve user ID from string:
    - "123" -> User(id=123)
    - "jdoe" -> User(username="jdoe")
    """
    if not created_by:
        return None

    # Case 1: Integer-like string
    if created_by.isdigit():
        uid = int(created_by)
        user = db.query(User).filter(User.id == uid).first()
        if user:
            return user.id
        else:
            return None  # Deleted user or unmatched ID

    # Case 2: Username
    user = db.query(User).filter(User.username == created_by).first()
    if user:
        return user.id

    return None


def process_table(db: Session, model, dry_run: bool):
    table_name = model.__tablename__
    logger.info(f"Scanning table: {table_name}")

    # Query for rows needing backfill
    query = db.query(model).filter(
        model.created_by.isnot(None), model.created_by_id.is_(None)
    )

    total_needing = query.count()
    if total_needing == 0:
        logger.info("  - No rows to backfill.")
        return

    logger.info(f"  - Needing backfill: {total_needing}")

    logger.info(f"  - Needing backfill: {total_needing}")

    updates = 0

    # -- ID ITERATOR RE-IMPLEMENTATION --

    last_id = 0
    scanned_count = 0

    while True:
        # Get next batch of IDs greater than last_id that match criteria
        rows = (
            db.query(model)
            .filter(
                model.created_by.isnot(None),
                model.created_by_id.is_(None),
                model.id > last_id,
            )
            .order_by(model.id.asc())
            .limit(BATCH_SIZE)
            .all()
        )

        if not rows:
            break

        batch_updates = 0

        for row in rows:
            last_id = row.id  # Track progress

            new_id = resolve_user_id(db, row.created_by)

            if new_id:
                if not dry_run:
                    row.created_by_id = new_id
                batch_updates += 1
            else:
                if dry_run or scanned_count < 5:  # Limit log noise
                    logger.warning(
                        f"  - Unresolved: {table_name}:{row.id} user='{row.created_by}'"
                    )

        if not dry_run and batch_updates > 0:
            db.commit()

        logger.info(f"  - Scanned {len(rows)}, Resolved {batch_updates}")
        scanned_count += len(rows)

    logger.info(f"Table {table_name} finished. Total resolved: {updates}")


def main():
    parser = argparse.ArgumentParser(description="Backfill created_by_id")
    parser.add_argument("--dry-run", action="store_true", help="Do not commit changes")
    args = parser.parse_args()

    print_banner(args.dry_run)

    db = SessionLocal()
    try:
        for model in MODELS_TO_BACKFILL:
            try:
                process_table(db, model, args.dry_run)
            except Exception as e:
                logger.error(f"Error processing {model.__tablename__}: {e}")
                db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    main()
