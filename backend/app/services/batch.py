"""
Service functions for batch management.
Handles creation, retrieval, update, and deletion of inventory batches.
"""

import logging
from datetime import date, datetime
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.models.batch import Batch
from app.db.schemas.batch import BatchCreate, BatchUpdate
from sqlalchemy import and_
from sqlalchemy.orm import Session

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
            .with_for_update()
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

        from app.utils.audit import resolve_user_audit

        user_name, user_id = resolve_user_audit(db, created_by)

        new_batch = Batch(
            **batch.dict(),
            created_by=user_name,
            created_by_id=user_id,
            updated_by=user_name,
        )
        db.add(new_batch)
        db.commit()
        db.refresh(new_batch)
        logger.debug(f"Created new batch id={new_batch.id}")
        return new_batch
    except Exception:
        logger.exception("Failed to create/update batch")
        raise AppException("Batch creation failed", status_code=500)


def get_batch(db: Session, batch_id: int) -> Batch:
    """
    Retrieve a batch by ID.

    Args:
        db (Session): Database session.
        batch_id (int): Batch ID.

    Returns:
        Batch: The batch record.

    Raises:
        AppException: If batch not found.
    """
    logger.info(f"Retrieving batch id={batch_id}")
    batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if not batch:
        logger.error(f"Batch not found id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return batch


def get_all_batches(db: Session, skip: int = 0, limit: int = 100) -> List[Batch]:
    """
    List all batches with pagination.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.

    Returns:
        List[Batch]: List of batch records.
    """
    logger.info(f"Listing batches skip={skip}, limit={limit}")
    from app.utils.pagination import get_pagination_params

    offset, limit = get_pagination_params(skip=skip, limit=limit)
    return db.query(Batch).offset(offset).limit(limit).all()


def get_batches_by_item_with_quantity(db: Session, item_id: int) -> List[Batch]:
    """
    List batches for a specific item with available quantity.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        List[Batch]: List of batch records.
    """
    logger.info(f"Listing batches for item_id={item_id} with quantity > 0")
    batches = (
        db.query(Batch)
        .filter(Batch.item_id == item_id, Batch.quantity > 0)
        .order_by(Batch.received_at.desc())
        .all()
    )
    return batches


def update_batch(
    db: Session,
    batch_id: int,
    entry_update: BatchUpdate,
    updated_by: Optional[str] = None,
) -> Batch:
    """
    Update fields of an existing batch.

    Args:
        db (Session): Database session.
        batch_id (int): Batch ID.
        entry_update (BatchUpdate): Fields to update.
        updated_by (Optional[str]): Updater identifier.

    Returns:
        Batch: Updated batch.

    Raises:
        AppException: If batch not found.
    """
    logger.info(f"Updating batch id={batch_id}")
    batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if not batch:
        logger.error(f"Batch not found id={batch_id}")
        raise AppException("Batch not found", status_code=404)

    for field, value in entry_update.dict(exclude_unset=True).items():
        setattr(batch, field, value)
    batch.updated_by = updated_by
    batch.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(batch)
    logger.debug(f"Batch id={batch_id} updated")
    return batch


def delete_batch(db: Session, batch_id: int) -> None:
    """
    Delete a batch by ID.

    Args:
        db (Session): Database session.
        batch_id (int): Batch ID.

    Raises:
        AppException: If batch not found.
    """
    logger.info(f"Deleting batch id={batch_id}")
    batch = db.query(Batch).filter(Batch.id == batch_id).first()
    if not batch:
        logger.error(f"Batch not found id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    db.delete(batch)
    db.commit()
    logger.debug(f"Batch id={batch_id} deleted")
