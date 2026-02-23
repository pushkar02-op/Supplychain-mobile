"""
API endpoints for dispatch entry management.
Provides CRUD operations and batch dispatch creation from orders.
"""

import logging
from datetime import date
from typing import List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.dispatch_entry import DispatchEntry  # Added
from app.db.models.user import User
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryMultiCreate,
    DispatchEntryNetRead,
    DispatchEntryRead,
    DispatchReversalCreate,
    DispatchReversalRead,
)
from app.db.session import get_db
from app.services.dispatch_entry import (
    create_dispatch_entry,
    create_dispatch_from_order,
    create_reversal_entry,
    get_all_dispatch_entries,
    get_dispatch_entry,
)
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/dispatch-entries", tags=["Dispatch Entries"])


@router.post("/", response_model=DispatchEntryRead, status_code=status.HTTP_201_CREATED)
def create_route(
    entry: DispatchEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
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
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
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


@router.get("/", response_model=List[DispatchEntryNetRead])
def get_dispatches(
    skip: int = 0,
    limit: int = 100,
    dispatch_date: Optional[date] = Query(None),
    mart_name: Optional[str] = Query(None),
    hide_fully_reversed: bool = Query(False),
    db: Session = Depends(get_db),
) -> List[DispatchEntry]:
    """
    Retrieve all dispatch entries.
    Returns Net View (net_quantity, status).
    """
    logger.info(
        f"Fetching dispatch entries skip={skip}, limit={limit}, hide_reversed={hide_fully_reversed}"
    )
    return get_all_dispatch_entries(
        db=db,
        skip=skip,
        limit=limit,
        dispatch_date=dispatch_date,
        mart_name=mart_name,
        hide_fully_reversed=hide_fully_reversed,
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


@router.post(
    "/{id}/reverse",
    response_model=DispatchReversalRead,
    status_code=status.HTTP_201_CREATED,
)
def reverse_dispatch(
    id: int,
    entry: DispatchReversalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> DispatchReversalRead:
    """
    Reverse a dispatch entry (Admin Only).
    """
    logger.info(f"Reversing dispatch {id} by user {current_user.username}")

    return create_reversal_entry(db, id, entry, created_by=current_user.username)
