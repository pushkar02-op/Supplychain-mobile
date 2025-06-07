"""
Service functions for batch management.
Handles creation, retrieval, update, and deletion of inventory batches.
"""

import logging
from datetime import date, datetime
from typing import List, Optional
from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.core.exceptions import AppException
from app.db.models import Batch
from app.db.schemas.batch import BatchCreate, BatchUpdate

logger = logging.getLogger(__name__)


def create_batch(
    db: Session, batch: BatchCreate, created_by: Optional[str] = None
) -> Batch:
    """
    Create or update a batch for today. If one exists, increase its quantity.

    Args:
        db (Session): Database session.
        batch (BatchCreate): Batch creation data.
        created_by (Optional[str]): Creator identifier.

    Returns:
        Batch: The created or updated batch record.
    """
    logger.info(
        f"Creating/updating batch for item_id={batch.item_id}, qty={batch.quantity}"
    )
    today = date.today()
    try:
        existing = (
            db.query(Batch)
            .filter(
                and_(
                    Batch.item_id == batch.item_id,
                    Batch.created_at >= datetime.combine(today, datetime.min.time()),
                    Batch.created_at <= datetime.combine(today, datetime.max.time()),
                )
            )
            .first()
        )
        if existing:
            existing.quantity += batch.quantity
            existing.updated_by = created_by
            existing.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(existing)
            logger.debug(
                f"Updated existing batch id={existing.id}, new qty={existing.quantity}"
            )
            return existing

        new_batch = Batch(
            **batch.dict(),
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(new_batch)
        db.commit()
        db.refresh(new_batch)
        logger.debug(f"Created new batch id={new_batch.id}")
        return new_batch
    except Exception as e:
        logger.exception("Failed to create/update batch")
        raise AppException("Batch creation failed", status_code=500)


def get_batch(db: Session, batch_id: int) -> Optional[Batch]:
    """
    Retrieve a batch by its ID.

    Args:
        db (Session): Database session.
        batch_id (int): Batch ID.

    Returns:
        Optional[Batch]: The batch or None.
    """
    logger.debug(f"Retrieving batch id={batch_id}")
    return db.query(Batch).filter(Batch.id == batch_id).first()


def get_all_batches(db: Session, skip: int = 0, limit: int = 100) -> List[Batch]:
    """
    Retrieve all batches with pagination.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.

    Returns:
        List[Batch]: List of batches.
    """
    logger.debug(f"Fetching all batches skip={skip}, limit={limit}")
    return db.query(Batch).offset(skip).limit(limit).all()


def update_batch(
    db: Session, batch_id: int, entry_update: BatchUpdate, updated_by: Optional[str]
) -> Optional[Batch]:
    """
    Update fields of an existing batch.

    Args:
        db (Session): Database session.
        batch_id (int): Batch ID.
        entry_update (BatchUpdate): Fields to update.
        updated_by (Optional[str]): Updater identifier.

    Returns:
        Optional[Batch]: Updated batch or None.
    """
    logger.info(f"Updating batch id={batch_id}")
    batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if not batch:
        logger.error(f"Batch not found id={batch_id}")
        return None

    for field, value in entry_update.dict(exclude_unset=True).items():
        setattr(batch, field, value)
    batch.updated_by = updated_by
    batch.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(batch)
    logger.debug(f"Batch id={batch_id} updated")
    return batch


def delete_batch(db: Session, batch_id: int) -> bool:
    """
    Delete a batch by ID.

    Args:
        db (Session): Database session.
        batch_id (int): Batch ID.

    Returns:
        bool: True if deleted, False if not found.
    """
    logger.info(f"Deleting batch id={batch_id}")
    batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if not batch:
        logger.error(f"Batch not found id={batch_id}")
        return False
    db.delete(batch)
    db.commit()
    logger.debug(f"Batch id={batch_id} deleted")
    return True


def get_batches_by_item_with_quantity(db: Session, item_id: int) -> List[Batch]:
    """
    Retrieve batches for a given item that have positive quantity.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        List[Batch]: List of batches in stock.
    """
    logger.debug(f"Fetching positive-quantity batches for item_id={item_id}")
    stmt = (
        select(Batch)
        .where(Batch.item_id == item_id, Batch.quantity > 0)
        .order_by(Batch.created_at)
    )
    return db.scalars(stmt).all()
