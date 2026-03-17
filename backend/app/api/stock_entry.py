"""
API endpoints for stock entry management.
Provides CRUD operations and listing of stock entries.
"""

import logging
from datetime import date
from typing import Annotated, List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.stock_entry import (
    StockEntryCreate,
    StockEntryRead,
    StockEntryUpdate,
)
from app.db.session import get_db
from app.services.stock_entry import (
    create_stock_entry,
    delete_stock_entry,
    get_all_stock_entries,
    get_stock_entry,
    update_stock_entry,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Header, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/stock-entry", tags=["Stock Entry"])


@router.post("/", response_model=StockEntryRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: StockEntryCreate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
    idempotency_key: Annotated[str, Header()] = None,
) -> StockEntryRead:
    if not idempotency_key:
        raise AppException("Idempotency-Key header is required", status_code=400)
    """
    Create a new stock entry.

    Args:
        entry (StockEntryCreate): Stock entry data.
        db (Session): Database session dependency.

    Returns:
        StockEntryRead: The created stock entry.
    """
    logger.info("Creating new stock entry")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "create"
    )
    return create_stock_entry(
        db=db,
        entry=entry,
        created_by=current_user.id,
        idempotency_key=idempotency_key,
        warehouse_id=resolved_warehouse_id,
    )


@router.get("/", response_model=List[StockEntryRead], summary="List stock entries")
def read_all(
    date: Optional[date] = Query(None, description="Filter by date"),
    warehouse_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> List[StockEntryRead]:
    """
    Retrieve all stock entries with optional date filter.
    Includes current batch quantity for each entry.

    Args:
        date (Optional[date]): Filter by entry date.
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        db (Session): Database session dependency.

    Returns:
        List[StockEntryRead]: List of stock entries with batch quantities.
    """
    logger.info(f"Fetching stock entries date={date}, skip={skip}, limit={limit}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    entries = get_all_stock_entries(
        db=db, warehouse_id=resolved_warehouse_id, date=date, skip=skip, limit=limit
    )

    # Enrich with batch quantity
    result = []
    for entry in entries:
        entry_dict = {
            "id": entry.id,
            "item_id": entry.item_id,
            "batch_id": entry.batch_id,
            "batch_quantity": float(entry.batch.quantity) if entry.batch else None,
            "received_date": entry.received_date,
            "quantity": entry.quantity,
            "unit": entry.unit,
            "price_per_unit": entry.price_per_unit,
            "total_cost": entry.total_cost,
            "source": entry.source,
            "item": entry.item,
            "created_at": entry.created_at,
            "updated_at": entry.updated_at,
            "created_by": entry.created_by,
            "updated_by": entry.updated_by,
            "warehouse_id": entry.warehouse_id,
        }
        result.append(entry_dict)

    return result


@router.get(
    "/{stock_entry_id}", response_model=StockEntryRead, summary="Get stock entry by ID"
)
def read_one(
    stock_entry_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> StockEntryRead:
    """
    Retrieve a single stock entry by ID.

    Args:
        stock_entry_id (int): Stock entry ID.
        db (Session): Database session dependency.

    Returns:
        StockEntryRead: The stock entry.

    Raises:
        AppException: If entry not found (404).
    """
    logger.info(f"Fetching stock entry id={stock_entry_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    entry = get_stock_entry(
        db=db, stock_entry_id=stock_entry_id, warehouse_id=resolved_warehouse_id
    )
    if not entry:
        logger.error(f"Stock entry not found: id={stock_entry_id}")
        raise AppException("Stock entry not found", status_code=404)
    return entry


@router.put(
    "/{stock_entry_id}", response_model=StockEntryRead, summary="Update stock entry"
)
def update(
    stock_entry_id: int,
    entry_update: StockEntryUpdate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> StockEntryRead:
    """
    Update an existing stock entry.

    Args:
        stock_entry_id (int): Stock entry ID.
        entry_update (StockEntryUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        StockEntryRead: The updated entry.

    Raises:
        AppException: If entry not found (404).
    """
    logger.info(f"Updating stock entry id={stock_entry_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    entry = get_stock_entry(db=db, stock_entry_id=stock_entry_id)
    if entry and entry.warehouse_id != resolved_warehouse_id:
        raise AppException(
            "Unauthorized warehouse access",
            status_code=403,
            rule_id="AUT-004",
            metadata={"warehouse_id": resolved_warehouse_id},
        )
    updated = update_stock_entry(
        db=db,
        stock_entry_id=stock_entry_id,
        entry_update=entry_update,
        updated_by=current_user.id,
    )
    if not updated:
        logger.error(f"Stock entry not found: id={stock_entry_id}")
        raise AppException("Stock entry not found", status_code=404)
    return updated


@router.delete(
    "/{stock_entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete stock entry",
)
def delete(
    stock_entry_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> None:
    """
    Delete a stock entry by ID.

    Args:
        stock_entry_id (int): Stock entry ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If entry not found (404).
    """
    logger.info(f"Deleting stock entry id={stock_entry_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "delete"
    )
    success = delete_stock_entry(
        db=db, stock_entry_id=stock_entry_id, warehouse_id=resolved_warehouse_id
    )
    if not success:
        logger.error(f"Stock entry not found: id={stock_entry_id}")
        raise AppException("Stock entry not found", status_code=404)
    return None
