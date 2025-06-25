"""
API endpoints for batch management.
Provides CRUD operations for batches, including creation, retrieval, update, and deletion.
"""

import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

from app.core.exceptions import AppException
from app.db.schemas.batch import BatchCreate, BatchRead, BatchUpdate
from app.services.batch import (
    create_batch,
    get_batch,
    get_all_batches,
    get_batches_by_item_with_quantity,
    update_batch,
    delete_batch,
)
from app.db.session import get_db
from app.core.auth import get_current_user
from app.db.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/batch", tags=["Batches"])


@router.post("/", response_model=BatchRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: BatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BatchRead:
    """
    Create a new batch entry.
    """
    logger.info(f"Creating new batch by {current_user.username}")
    return create_batch(db=db, entry=entry, created_by=current_user.username)


@router.get("/", response_model=List[BatchRead])
def read_all(
    skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
) -> List[BatchRead]:
    """
    Get all batch entries.

    Args:
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        db (Session): Database session dependency.

    Returns:
        List[BatchRead]: List of batch objects.
    """
    logger.info(f"Fetching batches skip={skip}, limit={limit}")
    return get_all_batches(db=db, skip=skip, limit=limit)


@router.get("/by-item/{item_id}", response_model=List[BatchRead])
def get_batches_by_item(item_id: int, db: Session = Depends(get_db)) -> List[BatchRead]:
    """
    Get batches for a specific item with available quantity.

    Args:
        item_id (int): The ID of the item.
        db (Session): Database session dependency.

    Returns:
        List[BatchRead]: List of batch objects for the item.
    """
    logger.info(f"Fetching batches for item_id={item_id}")
    return get_batches_by_item_with_quantity(db, item_id)


@router.get("/{batch_id}", response_model=BatchRead)
def read_one(batch_id: int, db: Session = Depends(get_db)) -> BatchRead:
    """
    Get a batch by ID.

    Args:
        batch_id (int): The ID of the batch to retrieve.
        db (Session): Database session dependency.

    Returns:
        BatchRead: The batch object.

    Raises:
        AppException: If the batch is not found (404).
    """
    logger.info(f"Fetching batch_id={batch_id}")
    batch = get_batch(db=db, batch_id=batch_id)
    if not batch:
        logger.error(f"Batch not found: batch_id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return batch


@router.put("/{batch_id}", response_model=BatchRead)
def update(
    batch_id: int,
    entry_update: BatchUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BatchRead:
    """
    Update a batch by ID.
    """
    logger.info(f"Updating batch_id={batch_id} by {current_user.username}")
    updated = update_batch(
        db=db, batch_id=batch_id, entry_update=entry_update, updated_by=current_user.username
    )
    if not updated:
        logger.error(f"Batch not found: batch_id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return updated


@router.delete("/{batch_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(batch_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a batch.

    Args:
        batch_id (int): The ID of the batch to delete.
        db (Session): Database session dependency.

    Returns:
        None

    Raises:
        AppException: If the batch is not found (404).
    """
    logger.info(f"Deleting batch_id={batch_id}")
    success = delete_batch(db=db, batch_id=batch_id)
    if not success:
        logger.error(f"Batch not found: batch_id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return None
