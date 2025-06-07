"""
API endpoints for item management.
Provides CRUD operations for items and retrieval of items with available batches.
"""

import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

from app.core.exceptions import AppException
from app.db.schemas.item import ItemCreate, ItemRead, ItemUpdate
from app.services.item import (
    create_item,
    get_item,
    get_all_items,
    get_items_with_available_batches,
    update_item,
    delete_item,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/item", tags=["Items"])


@router.post("/", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
def create(entry: ItemCreate, db: Session = Depends(get_db)) -> ItemRead:
    """
    Create a new item.

    Args:
        entry (ItemCreate): The item data to create.
        db (Session): Database session dependency.

    Returns:
        ItemRead: The created item object.
    """
    logger.info(f"Creating item: {entry.name}")
    return create_item(db=db, entry=entry, created_by=1)


@router.get("/", response_model=List[ItemRead], summary="List items")
def read_all(
    skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
) -> List[ItemRead]:
    """
    Retrieve all items.

    Args:
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        db (Session): Database session dependency.

    Returns:
        List[ItemRead]: List of item objects.
    """
    logger.info(f"Fetching items skip={skip}, limit={limit}")
    return get_all_items(db=db, skip=skip, limit=limit)


@router.get(
    "/with-available-batches",
    response_model=List[ItemRead],
    summary="List items with available batches",
)
def get_items_with_batches(db: Session = Depends(get_db)) -> List[ItemRead]:
    """
    Retrieve items that have available batches.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[ItemRead]: List of items with stock.
    """
    logger.info("Fetching items with available batches")
    return get_items_with_available_batches(db)


@router.get("/{item_id}", response_model=ItemRead, summary="Get item by ID")
def read_one(item_id: int, db: Session = Depends(get_db)) -> ItemRead:
    """
    Retrieve a single item by ID.

    Args:
        item_id (int): Item ID.
        db (Session): Database session dependency.

    Returns:
        ItemRead: The item object.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Fetching item id={item_id}")
    item = get_item(db=db, item_id=item_id)
    if not item:
        logger.error(f"Item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return item


@router.put("/{item_id}", response_model=ItemRead, summary="Update item")
def update(
    item_id: int, entry_update: ItemUpdate, db: Session = Depends(get_db)
) -> ItemRead:
    """
    Update an existing item by ID.

    Args:
        item_id (int): Item ID.
        entry_update (ItemUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        ItemRead: The updated item.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Updating item id={item_id}")
    updated = update_item(
        db=db, item_id=item_id, entry_update=entry_update, updated_by=1
    )
    if not updated:
        logger.error(f"Item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return updated


@router.delete(
    "/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete item"
)
def delete(item_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete an item by ID.

    Args:
        item_id (int): Item ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the item is not found (404).
    """
    logger.info(f"Deleting item id={item_id}")
    success = delete_item(db=db, item_id=item_id)
    if not success:
        logger.error(f"Item not found: id={item_id}")
        raise AppException("Item not found", status_code=404)
    return None
