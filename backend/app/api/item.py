"""
API endpoints for item management.
Provides CRUD operations for items and retrieval of items with available batches.
"""

import logging
from typing import List, Optional

from app.core.auth import get_current_user, require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.item import ItemCreate, ItemRead, ItemUpdate
from app.db.session import get_db
from app.services.item import (
    create_item,
    deactivate_item,
    get_all_items,
    get_item,
    get_items_with_available_batches,
    reactivate_item,
    update_item,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/item", tags=["Items"])


@router.post("/", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: ItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> ItemRead:
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
    skip: int = 0,
    limit: int = 100,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
) -> List[ItemRead]:
    """
    Retrieve all items.

    Args:
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        include_inactive (bool): If True, include INACTIVE items. Default: False.
        db (Session): Database session dependency.

    Returns:
        List[ItemRead]: List of item objects.
    """
    logger.info(
        f"Fetching items skip={skip}, limit={limit}, include_inactive={include_inactive}"
    )
    return get_all_items(
        db=db, skip=skip, limit=limit, include_inactive=include_inactive
    )


@router.get(
    "/with-available-batches",
    response_model=List[ItemRead],
    summary="List items with available batches",
)
def get_items_with_batches(
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> List[ItemRead]:
    """
    Retrieve items that have available batches.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[ItemRead]: List of items with stock.
    """
    logger.info("Fetching items with available batches")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="read",
    )
    return get_items_with_available_batches(db, warehouse_id=resolved_warehouse_id)


@router.get("/check-similarity", summary="Check for similar items (Advisory)")
def check_advisory_similarity(
    name: str,
    uom: Optional[str] = None,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Find similar items for soft duplicate awareness (Advisory Only).

    CRITICAL CONSTRAINT:
    This endpoint is advisory-only and must not be used for automation.
    It provides "Duplicate Awareness", not "Duplicate Prevention".

    Logic:
    - Basic name similarity (case-insensitive containment)
    - Optional base UOM filtering
    - No alias-based inference
    - No cross-mart intelligence

    Returns candidate list with basic metadata.
    """
    from app.services.item import search_advisory_name_matches

    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="read",
    )
    return search_advisory_name_matches(
        db=db,
        name=name,
        warehouse_id=resolved_warehouse_id,
        uom_code=uom,
    )


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
    item_id: int,
    entry_update: ItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
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
    "/{item_id}",
    status_code=status.HTTP_405_METHOD_NOT_ALLOWED,
    summary="Delete item (BLOCKED)",
)
def delete(
    item_id: int,
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> None:
    """
    Item deletion is not supported. Use archival instead.

    This endpoint is intentionally blocked per governance mandate.
    Items should be deactivated, not deleted, to preserve referential integrity.
    """
    raise AppException(
        detail="Item deletion is not supported. Use /item/{id}/deactivate instead.",
        status_code=status.HTTP_405_METHOD_NOT_ALLOWED,
        rule_id=None,
        metadata={},
    )


@router.post(
    "/{item_id}/deactivate", response_model=ItemRead, summary="Deactivate item"
)
def deactivate(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> ItemRead:
    """
    Deactivate an item (set status to INACTIVE).

    This is reversible via /item/{id}/reactivate.
    Idempotent: calling on already-inactive item returns success.
    Preserves all data and relationships.
    """
    logger.info(f"API: Deactivating item id={item_id}")
    item = deactivate_item(db=db, item_id=item_id)
    if not item:
        raise AppException("Item not found", status_code=404)
    return ItemRead.from_orm(item)


@router.post(
    "/{item_id}/reactivate", response_model=ItemRead, summary="Reactivate item"
)
def reactivate(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> ItemRead:
    """
    Reactivate an item (set status to ACTIVE).

    Idempotent: calling on already-active item returns success.
    """
    logger.info(f"API: Reactivating item id={item_id}")
    item = reactivate_item(db=db, item_id=item_id)
    if not item:
        raise AppException("Item not found", status_code=404)
    return ItemRead.from_orm(item)
