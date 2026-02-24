"""
API endpoints for batch management.
Provides CRUD operations for batches, including creation, retrieval, update, and deletion.
"""

import logging
from typing import List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.batch import BatchCreate, BatchRead, BatchUpdate
from app.db.session import get_db
from app.services.batch import (
    create_batch,
    delete_batch,
    get_all_batches,
    get_batch,
    get_batches_by_item_with_quantity,
    update_batch,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/batch", tags=["Batches"])


@router.post("/", response_model=BatchRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: BatchCreate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> BatchRead:
    """
    Create a new batch entry.

    Args:
        entry (BatchCreate): Batch creation data.
        db (Session): Database session dependency.
        current_user (User): Current authenticated user.

    Returns:
        BatchRead: The created batch object.
    """
    # SAFETY WARNING:
    # - This endpoint bypasses ledger logic
    # - It is admin-only by design
    # - It must be used only for controlled recovery or maintenance
    logger.info(f"Creating new batch by {current_user.username}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "create"
    )
    return create_batch(
        db=db,
        batch=entry,
        created_by=current_user.username,
        warehouse_id=resolved_warehouse_id,
    )


@router.get("/", response_model=List[BatchRead], summary="List batches")
def read_all(
    warehouse_id: Optional[int] = Query(None),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
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
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_all_batches(
        db=db, warehouse_id=resolved_warehouse_id, skip=skip, limit=limit
    )


@router.get(
    "/by-item/{item_id}", response_model=List[BatchRead], summary="List batches by item"
)
def get_batches_by_item(
    item_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> List[BatchRead]:
    """
    Get batches for a specific item with available quantity.

    Args:
        item_id (int): The ID of the item.
        db (Session): Database session dependency.

    Returns:
        List[BatchRead]: List of batch objects for the item.
    """
    logger.info(f"Fetching batches for item_id={item_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_batches_by_item_with_quantity(db, item_id, resolved_warehouse_id)


@router.get("/{batch_id}", response_model=BatchRead, summary="Get batch by ID")
def read_one(
    batch_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> BatchRead:
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
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    batch = get_batch(db=db, batch_id=batch_id, warehouse_id=resolved_warehouse_id)
    if not batch:
        logger.error(f"Batch not found: batch_id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return batch


@router.put("/{batch_id}", response_model=BatchRead, summary="Update batch")
def update(
    batch_id: int,
    entry_update: BatchUpdate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> BatchRead:
    """
    Update a batch by ID.

    Args:
        batch_id (int): The ID of the batch to update.
        entry_update (BatchUpdate): Fields to update.
        db (Session): Database session dependency.
        current_user (User): Current authenticated user.

    Returns:
        BatchRead: The updated batch object.

    Raises:
        AppException: If the batch is not found (404).
    """
    # SAFETY WARNING:
    # - This endpoint bypasses ledger logic
    # - It is admin-only by design
    # - It must be used only for controlled recovery or maintenance
    logger.info(f"Updating batch_id={batch_id} by {current_user.username}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    updated = update_batch(
        db=db,
        batch_id=batch_id,
        entry_update=entry_update,
        updated_by=current_user.username,
        warehouse_id=resolved_warehouse_id,
    )
    if not updated:
        logger.error(f"Batch not found: batch_id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return updated


@router.delete(
    "/{batch_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete batch"
)
def delete(
    batch_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> None:
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
    # SAFETY WARNING:
    # - This endpoint bypasses ledger logic
    # - It is admin-only by design
    # - It must be used only for controlled recovery or maintenance
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "delete"
    )
    success = delete_batch(
        db=db,
        batch_id=batch_id,
        warehouse_id=resolved_warehouse_id,
        deleted_by_user_id=current_user.id,
    )
    if not success:
        logger.error(f"Batch not found: batch_id={batch_id}")
        raise AppException("Batch not found", status_code=404)
    return None
