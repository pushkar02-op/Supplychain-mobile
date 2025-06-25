"""
API endpoints for dispatch entry management.
Provides CRUD operations and batch dispatch creation from orders.
"""

import logging
from datetime import date
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.core.auth import get_current_user
from app.core.exceptions import AppException
from app.db.models.user import User
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryRead,
    DispatchEntryUpdate,
    DispatchEntryMultiCreate,
)
from app.services.dispatch_entry import (
    create_dispatch_entry,
    get_dispatch_entry,
    get_all_dispatch_entries,
    update_dispatch_entry,
    delete_dispatch_entry,
    create_dispatch_from_order,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/dispatch-entries", tags=["Dispatch Entries"])


@router.post("/", response_model=DispatchEntryRead, status_code=status.HTTP_201_CREATED)
def create_route(
    entry: DispatchEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DispatchEntryRead:
    """
    Create a new dispatch entry.

    Args:
        entry (DispatchEntryCreate): Dispatch entry data.
        db (Session): Database session dependency.

    Returns:
        DispatchEntryRead: The created dispatch entry.
    """
    logger.info("Creating new dispatch entry")
    return create_dispatch_entry(db, entry, created_by=current_user.username)


@router.post(
    "/from-order",
    response_model=List[DispatchEntryRead],
    status_code=status.HTTP_201_CREATED,
)
def dispatch_from_order(
    entry: DispatchEntryMultiCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> List[DispatchEntryRead]:
    """
    Create multiple dispatch entries from an order.

    Args:
        entry (DispatchEntryMultiCreate): Order-based dispatch data.
        db (Session): Database session dependency.

    Returns:
        List[DispatchEntryRead]: List of created dispatch entries.

    Raises:
        AppException: If creation fails (400).
    """
    logger.info("Creating dispatch entries from order")
    try:
        return create_dispatch_from_order(db, entry, created_by=current_user.username)
    except Exception as e:
        logger.exception("Failed to create dispatch from order")
        raise AppException(str(e), status_code=400)


@router.get("/", response_model=List[DispatchEntryRead])
def read_all(
    skip: int = 0,
    limit: int = 100,
    dispatch_date: Optional[date] = Query(None),
    mart_name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
) -> List[DispatchEntryRead]:
    """
    Retrieve all dispatch entries with optional filters.

    Args:
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        dispatch_date (Optional[date]): Filter by dispatch date.
        mart_name (Optional[str]): Filter by mart name.
        db (Session): Database session dependency.

    Returns:
        List[DispatchEntryRead]: List of dispatch entries.
    """
    logger.info(f"Fetching dispatch entries skip={skip}, limit={limit}")
    return get_all_dispatch_entries(
        db=db,
        skip=skip,
        limit=limit,
        dispatch_date=dispatch_date,
        mart_name=mart_name,
    )


@router.get("/{id}", response_model=DispatchEntryRead)
def read_one(id: int, db: Session = Depends(get_db)) -> DispatchEntryRead:
    """
    Retrieve a single dispatch entry by ID.

    Args:
        id (int): Dispatch entry ID.
        db (Session): Database session dependency.

    Returns:
        DispatchEntryRead: The dispatch entry.

    Raises:
        AppException: If the entry is not found (404).
    """
    logger.info(f"Fetching dispatch entry id={id}")
    entry = get_dispatch_entry(db, id)
    if not entry:
        logger.error(f"Dispatch entry not found: id={id}")
        raise AppException("Dispatch entry not found", status_code=404)
    return entry


@router.put("/{id}", response_model=DispatchEntryRead)
def update_route(
    id: int,
    entry: DispatchEntryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DispatchEntryRead:
    """
    Update a dispatch entry by ID.

    Args:
        id (int): Dispatch entry ID.
        entry (DispatchEntryUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        DispatchEntryRead: The updated dispatch entry.

    Raises:
        AppException: If the entry is not found (404).
    """
    logger.info(f"Updating dispatch entry id={id}")
    updated = update_dispatch_entry(db, id, entry, updated_by=current_user.username)
    if not updated:
        logger.error(f"Dispatch entry not found: id={id}")
        raise AppException("Dispatch entry not found", status_code=404)
    return updated


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_route(id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a dispatch entry by ID.

    Args:
        id (int): Dispatch entry ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the entry is not found (404).
    """
    logger.info(f"Deleting dispatch entry id={id}")
    success = delete_dispatch_entry(db, id)
    if not success:
        logger.error(f"Dispatch entry not found: id={id}")
        raise AppException("Dispatch entry not found", status_code=404)
    return None
