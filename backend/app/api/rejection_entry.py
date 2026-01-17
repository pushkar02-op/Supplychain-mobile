"""
API endpoints for rejection entry management.
Provides creation and retrieval of rejection entries, with optional filtering.
"""

import logging
from datetime import date
from typing import Annotated, List, Optional

from app.core.auth import get_current_user
from app.core.exceptions import AppException
from app.db.models.user import User
from app.db.schemas.rejection_entry import (
    RejectionEntryCreate,
    RejectionEntryRead,
    RejectionPagination,
)
from app.db.session import get_db
from app.services.rejection_entry import (
    create_rejection_entry,
    get_all_rejections,
    get_rejections_by_date_and_items,
)
from fastapi import APIRouter, Depends, Header, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/rejection-entries", tags=["Rejection Entries"])


@router.post(
    "/", response_model=RejectionEntryRead, status_code=status.HTTP_201_CREATED
)
def create_route(
    entry: RejectionEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    idempotency_key: Annotated[str, Header()] = None,
) -> RejectionEntryRead:
    if not idempotency_key:
        raise AppException("Idempotency-Key header is required", status_code=400)
    """
    Create a new rejection entry.

    Args:
        entry (RejectionEntryCreate): Rejection data.
        db (Session): Database session dependency.

    Returns:
        RejectionEntryRead: The created rejection entry.
    """
    logger.info("Creating new rejection entry")
    return create_rejection_entry(
        db=db, entry=entry, created_by="system", idempotency_key=idempotency_key
    )


@router.get("/", response_model=List[RejectionEntryRead], summary="List rejections")
def read_all(db: Session = Depends(get_db)) -> List[RejectionEntryRead]:
    """
    Retrieve all rejection entries.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[RejectionEntryRead]: List of rejections.
    """
    logger.info("Fetching all rejection entries")
    return get_all_rejections(db)


@router.get("/list", response_model=RejectionPagination, summary="Filter rejections")
def get_filtered_rejections(
    rejection_date: date = Query(..., description="Rejection date"),
    item_ids: Optional[List[int]] = Query(None, description="Filter by item IDs"),
    skip: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(50, ge=1, le=100, description="Items per page"),
    db: Session = Depends(get_db),
) -> RejectionPagination:
    """
    Retrieve rejection entries filtered by date and item IDs with pagination.

    Args:
        rejection_date (date): Date to filter rejections.
        item_ids (Optional[List[int]]): List of item IDs to filter.
        skip (int): Pagination offset.
        limit (int): Pagination limit.
        db (Session): Database session dependency.

    Returns:
        RejectionPagination: Paginated list of filtered rejections.
    """
    logger.info(
        f"Fetching rejections for date={rejection_date}, item_ids={item_ids}, skip={skip}, limit={limit}"
    )
    return get_rejections_by_date_and_items(
        db=db, rejection_date=rejection_date, item_ids=item_ids, skip=skip, limit=limit
    )


@router.delete(
    "/{id}", status_code=status.HTTP_204_NO_CONTENT, summary="Reverse rejection"
)
def reverse_rejection(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Reverse a rejection entry. See docs/architecture/rejections-model.md.
    """
    from app.services.rejection_entry import reverse_rejection_entry

    logger.info(f"User {current_user.id} reversing rejection {id}")
    reverse_rejection_entry(db, id, current_user.id)
    return None
