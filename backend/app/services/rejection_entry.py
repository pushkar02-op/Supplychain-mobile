"""
Service functions for rejection entry management.
Handles creation and queries of rejection logs.
"""

import logging
from datetime import date
from decimal import Decimal
from typing import List, Optional

from app.core.exceptions import AppException, UOMConfigurationError
from app.db.models.batch import Batch
from app.db.models.rejection_entry import RejectionEntry
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_rejection_entry(
    db: Session,
    entry: RejectionEntryCreate,
    created_by: Optional[str] = None,
    idempotency_key: Optional[str] = None,
) -> RejectionEntry:
    """
    Create a rejection entry and decrement batch quantity.

    Args:
        db (Session): Database session.
        entry (RejectionEntryCreate): Rejection data.
        created_by (Optional[str]): Creator ID.

    Returns:
        RejectionEntry: Created rejection record.

    Raises:
        AppException: If batch invalid or insufficient quantity.
    """
    logger.info(
        f"Creating rejection entry for batch_id={entry.batch_id}, qty={entry.quantity}, idempotency_key={idempotency_key}"
    )

    if idempotency_key:
        from app.utils.idempotency import check_idempotency, save_idempotency_record

        existing_record = check_idempotency(
            db, idempotency_key, "create_rejection_entry", entry.dict()
        )
        if existing_record:
            return db.get(RejectionEntry, existing_record.result_entity_id)

    # Lock batch to prevent overselling during rejection
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).with_for_update().first()
    if not batch:
        logger.error(f"Batch not found id={entry.batch_id}")
        raise AppException("Batch not found", status_code=404)
    if batch.quantity < entry.quantity:
        msg = f"Cannot reject {entry.quantity}. Only {batch.quantity} available"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    rej = RejectionEntry(
        **entry.dict(),
        unit=batch.unit,
        item_id=batch.item_id,
        created_by=user_name,
        created_by_id=user_id,
        updated_by=user_name,
    )
    try:
        db.add(rej)
        # Direct NUMERIC update (Stage 3: Cleanup)
        batch.quantity -= Decimal(str(entry.quantity))
        db.flush()
        db.refresh(rej)
        logger.debug(f"Created rejection id={rej.id}")

        try:
            from app.db.models.item import Item

            item = db.get(Item, batch.item_id)
            if not item or not item.default_uom_code:
                raise UOMConfigurationError(
                    f"Item id={batch.item_id} has no default UOM configured. Cannot record rejection ledger."
                )
            target_unit = item.default_uom_code

            factor = get_conversion_factor(db, batch.item_id, batch.unit, target_unit)
        except AppException as e:
            logger.error(f"Conversion lookup failed: {e}")
            raise

        base_qty = Decimal(str(entry.quantity)) * factor

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=batch.item_id,
                batch_id=entry.batch_id,
                txn_type="OUT",
                raw_qty=entry.quantity,
                raw_unit=batch.unit,
                base_qty=base_qty,
                base_unit=target_unit,
                ref_type="rejection_entry",
                ref_id=rej.id,
                remarks="Stock removed via rejection",
            ),
        )
        db.flush()  # Ensure ID is generated before commit

        if idempotency_key:
            save_idempotency_record(
                db,
                idempotency_key,
                "create_rejection_entry",
                entry.dict(),
                "rejection_entry",
                rej.id,
            )

        db.commit()
        return rej
    except Exception:
        db.rollback()
        logger.exception("Failed to create rejection entry")
        raise AppException("Rejection entry creation failed", status_code=500)


def get_all_rejections(db: Session) -> List[RejectionEntry]:
    """
    Retrieve all rejection entries ordered by date desc.

    Args:
        db (Session): Database session.

    Returns:
        List[RejectionEntry]: List of rejections.
    """
    logger.debug("Fetching all rejection entries")
    return db.query(RejectionEntry).order_by(RejectionEntry.rejection_date.desc()).all()


def get_rejections_by_date_and_items(
    db: Session, rejection_date: date, item_ids: Optional[List[int]] = None
) -> List[RejectionEntry]:
    """
    Retrieve rejections filtered by date and optional item IDs.

    Args:
        db (Session): Database session.
        rejection_date (date): Filter date.
        item_ids (Optional[List[int]]): Filter item IDs.

    Returns:
        List[RejectionEntry]: Filtered rejections.
    """
    logger.debug(f"Fetching rejections for date={rejection_date}, items={item_ids}")
    q = db.query(RejectionEntry).filter(RejectionEntry.rejection_date == rejection_date)
    if item_ids:
        q = q.filter(RejectionEntry.item_id.in_(item_ids))
    return q.order_by(RejectionEntry.created_at.desc()).all()
