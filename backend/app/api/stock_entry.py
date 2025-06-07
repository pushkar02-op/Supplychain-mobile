"""
API endpoints for stock entry management.
Provides CRUD operations and listing of stock entries.
"""

import logging
from datetime import date
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.schemas.stock_entry import (
    StockEntryCreate,
    StockEntryRead,
    StockEntryUpdate,
)
from app.services.stock_entry import (
    create_stock_entry,
    get_stock_entry,
    get_all_stock_entries,
    update_stock_entry,
    delete_stock_entry,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/stock-entry", tags=["Stock Entry"])


@router.post("/", response_model=StockEntryRead, status_code=status.HTTP_201_CREATED)
def create(entry: StockEntryCreate, db: Session = Depends(get_db)) -> StockEntryRead:
    """
    Create a new stock entry.

    Args:
        entry (StockEntryCreate): Stock entry data.
        db (Session): Database session dependency.

    Returns:
        StockEntryRead: The created stock entry.
    """
    logger.info("Creating new stock entry")
    return create_stock_entry(db=db, entry=entry, created_by=1)


@router.get("/", response_model=List[StockEntryRead], summary="List stock entries")
def read_all(
    date: Optional[date] = Query(None, description="Filter by date"),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
) -> List[StockEntryRead]:
    """
    Retrieve all stock entries with optional date filter.

    Args:
        date (Optional[date]): Filter by entry date.
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        db (Session): Database session dependency.

    Returns:
        List[StockEntryRead]: List of stock entries.
    """
    logger.info(f"Fetching stock entries date={date}, skip={skip}, limit={limit}")
    return get_all_stock_entries(db=db, date=date, skip=skip, limit=limit)


@router.get(
    "/{stock_entry_id}", response_model=StockEntryRead, summary="Get stock entry by ID"
)
def read_one(stock_entry_id: int, db: Session = Depends(get_db)) -> StockEntryRead:
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
    entry = get_stock_entry(db=db, stock_entry_id=stock_entry_id)
    if not entry:
        logger.error(f"Stock entry not found: id={stock_entry_id}")
        raise AppException("Stock entry not found", status_code=404)
    return entry


@router.put(
    "/{stock_entry_id}", response_model=StockEntryRead, summary="Update stock entry"
)
def update(
    stock_entry_id: int, entry_update: StockEntryUpdate, db: Session = Depends(get_db)
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
    updated = update_stock_entry(
        db=db, stock_entry_id=stock_entry_id, entry_update=entry_update, updated_by=1
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
def delete(stock_entry_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a stock entry by ID.

    Args:
        stock_entry_id (int): Stock entry ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If entry not found (404).
    """
    logger.info(f"Deleting stock entry id={stock_entry_id}")
    success = delete_stock_entry(db=db, stock_entry_id=stock_entry_id)
    if not success:
        logger.error(f"Stock entry not found: id={stock_entry_id}")
        raise AppException("Stock entry not found", status_code=404)
    return None
