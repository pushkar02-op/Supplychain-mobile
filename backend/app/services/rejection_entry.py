"""
Service functions for rejection entry management.
Handles creation and queries of rejection logs.
"""

import logging
from datetime import date
from typing import List, Optional

from sqlalchemy.orm import Session

from app.core.exceptions import AppException
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.batch import Batch
from app.db.schemas.rejection_entry import RejectionEntryCreate

logger = logging.getLogger(__name__)


def create_rejection_entry(
    db: Session, entry: RejectionEntryCreate, created_by: Optional[str] = None
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
        f"Creating rejection entry for batch_id={entry.batch_id}, qty={entry.quantity}"
    )
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).first()
    if not batch:
        logger.error(f"Batch not found id={entry.batch_id}")
        raise AppException("Batch not found", status_code=404)
    if batch.quantity < entry.quantity:
        msg = f"Cannot reject {entry.quantity}. Only {batch.quantity} available"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    rej = RejectionEntry(
        **entry.dict(),
        unit=batch.unit,
        item_id=batch.item_id,
        created_by=created_by,
        updated_by=created_by,
    )
    try:
        db.add(rej)
        batch.quantity -= entry.quantity
        db.commit()
        db.refresh(rej)
        logger.debug(f"Created rejection id={rej.id}")
        return rej
    except Exception as e:
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
