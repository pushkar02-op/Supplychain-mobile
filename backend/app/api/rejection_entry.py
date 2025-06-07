"""
API endpoints for rejection entry management.
Provides creation and retrieval of rejection entries, with optional filtering.
"""

import logging
from datetime import date
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.schemas.rejection_entry import (
    RejectionEntryCreate,
    RejectionEntryRead,
)
from app.services.rejection_entry import (
    create_rejection_entry,
    get_all_rejections,
    get_rejections_by_date_and_items,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/rejection-entries", tags=["Rejection Entries"])


@router.post(
    "/", response_model=RejectionEntryRead, status_code=status.HTTP_201_CREATED
)
def create_route(
    entry: RejectionEntryCreate, db: Session = Depends(get_db)
) -> RejectionEntryRead:
    """
    Create a new rejection entry.

    Args:
        entry (RejectionEntryCreate): Rejection data.
        db (Session): Database session dependency.

    Returns:
        RejectionEntryRead: The created rejection entry.
    """
    logger.info("Creating new rejection entry")
    return create_rejection_entry(db=db, entry=entry, created_by="system")


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


@router.get(
    "/list", response_model=List[RejectionEntryRead], summary="Filter rejections"
)
def get_filtered_rejections(
    rejection_date: date = Query(..., description="Rejection date"),
    item_ids: Optional[List[int]] = Query(None, description="Filter by item IDs"),
    db: Session = Depends(get_db),
) -> List[RejectionEntryRead]:
    """
    Retrieve rejection entries filtered by date and item IDs.

    Args:
        rejection_date (date): Date to filter rejections.
        item_ids (Optional[List[int]]): List of item IDs to filter.
        db (Session): Database session dependency.

    Returns:
        List[RejectionEntryRead]: List of filtered rejections.
    """
    logger.info(f"Fetching rejections for date={rejection_date}, item_ids={item_ids}")
    return get_rejections_by_date_and_items(
        db=db, rejection_date=rejection_date, item_ids=item_ids
    )
