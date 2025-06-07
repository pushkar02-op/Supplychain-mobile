"""
API endpoints for item conversion map management.
Provides CRUD operations to manage unit/item conversion mappings.
"""

import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

from app.core.exceptions import AppException
from app.db.schemas.item_conversion_map import (
    ItemConversionCreate,
    ItemConversionRead,
    ItemConversionUpdate,
)
from app.services.item_conversion_map import (
    create_conversion,
    get_all_conversions,
    get_conversion,
    update_conversion,
    delete_conversion,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/conversions", tags=["Item Conversions"])


@router.post(
    "/", response_model=ItemConversionRead, status_code=status.HTTP_201_CREATED
)
def create_conv(
    entry: ItemConversionCreate, db: Session = Depends(get_db)
) -> ItemConversionRead:
    """
    Create a new item conversion mapping.

    Args:
        entry (ItemConversionCreate): Conversion details.
        db (Session): Database session dependency.

    Returns:
        ItemConversionRead: The created conversion mapping.
    """
    logger.info("Creating new item conversion mapping")
    return create_conversion(db=db, entry=entry, created_by="system")


@router.get("/", response_model=List[ItemConversionRead], summary="List conversions")
def list_convs(db: Session = Depends(get_db)) -> List[ItemConversionRead]:
    """
    Retrieve all item conversion mappings.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[ItemConversionRead]: List of conversion mappings.
    """
    logger.info("Fetching all item conversion mappings")
    return get_all_conversions(db)


@router.get(
    "/{conv_id}", response_model=ItemConversionRead, summary="Get conversion by ID"
)
def read_conv(conv_id: int, db: Session = Depends(get_db)) -> ItemConversionRead:
    """
    Retrieve a single conversion mapping by ID.

    Args:
        conv_id (int): Conversion mapping ID.
        db (Session): Database session dependency.

    Returns:
        ItemConversionRead: The conversion mapping.

    Raises:
        AppException: If mapping not found (404).
    """
    logger.info(f"Fetching conversion id={conv_id}")
    conv = get_conversion(db, conv_id)
    if not conv:
        logger.error(f"Conversion not found: id={conv_id}")
        raise AppException("Conversion not found", status_code=404)
    return conv


@router.put(
    "/{conv_id}", response_model=ItemConversionRead, summary="Update conversion"
)
def update_conv(
    conv_id: int, entry: ItemConversionUpdate, db: Session = Depends(get_db)
) -> ItemConversionRead:
    """
    Update an existing conversion mapping.

    Args:
        conv_id (int): Conversion mapping ID.
        entry (ItemConversionUpdate): Updated conversion data.
        db (Session): Database session dependency.

    Returns:
        ItemConversionRead: The updated conversion mapping.

    Raises:
        AppException: If mapping not found (404).
    """
    logger.info(f"Updating conversion id={conv_id}")
    updated = update_conversion(db, conv_id, entry, updated_by="system")
    if not updated:
        logger.error(f"Conversion not found: id={conv_id}")
        raise AppException("Conversion not found", status_code=404)
    return updated


@router.delete(
    "/{conv_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete conversion"
)
def delete_conv(conv_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a conversion mapping by ID.

    Args:
        conv_id (int): Conversion mapping ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If mapping not found (404).
    """
    logger.info(f"Deleting conversion id={conv_id}")
    success = delete_conversion(db, conv_id)
    if not success:
        logger.error(f"Conversion not found: id={conv_id}")
        raise AppException("Conversion not found", status_code=404)
    return None
