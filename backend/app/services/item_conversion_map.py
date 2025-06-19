"""
Service functions for item conversion mapping.
Handles CRUD operations on unit/item conversion mappings.
"""

import logging
from typing import List, Optional

from sqlalchemy.orm import Session

from app.core.exceptions import AppException
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.schemas.item_conversion_map import (
    ItemConversionCreate,
    ItemConversionUpdate,
)

logger = logging.getLogger(__name__)


def get_conversion_factor(
    db: Session, item_id: int, from_unit: str, to_unit: str
) -> float:
    """
    Returns the conversion factor to convert from 'from_unit' to 'to_unit' for a given item.
    If from_unit == to_unit, returns 1.0.
    Raises AppException if no conversion is found.
    """
    if from_unit == to_unit:
        return 1.0

    conv = (
        db.query(ItemConversionMap)
        .filter_by(item_id=item_id, source_unit=from_unit, target_unit=to_unit)
        .first()
    )
    if conv:
        return conv.conversion_factor

    conv_rev = (
        db.query(ItemConversionMap)
        .filter_by(item_id=item_id, source_unit=to_unit, target_unit=from_unit)
        .first()
    )
    if conv_rev and conv_rev.conversion_factor != 0:
        logger.warning(
            f"Using reverse conversion for item_id={item_id} from {to_unit} to {from_unit}"
        )
        return 1.0 / conv_rev.conversion_factor

    raise AppException(
        f"No conversion factor found for item_id={item_id} from '{from_unit}' to '{to_unit}'"
    )


def create_conversion(
    db: Session, data: ItemConversionCreate, created_by: str
) -> ItemConversionMap:
    """
    Create a new conversion mapping.

    Args:
        db (Session): Database session.
        data (ItemConversionCreate): Conversion data.
        created_by (str): Creator ID.

    Returns:
        ItemConversionMap: Created mapping.
    """
    logger.info("Creating item conversion mapping")
    conv = ItemConversionMap(
        **data.dict(), created_by=created_by, updated_by=created_by
    )
    db.add(conv)
    db.commit()
    db.refresh(conv)
    logger.debug(f"Created conversion id={conv.id}")
    return conv


def get_all_conversions(db: Session) -> List[ItemConversionMap]:
    """
    Retrieve all conversion mappings.

    Args:
        db (Session): Database session.

    Returns:
        List[ItemConversionMap]: All mappings.
    """
    logger.debug("Fetching all conversion mappings")
    return db.query(ItemConversionMap).all()


def get_conversion(db: Session, conv_id: int) -> Optional[ItemConversionMap]:
    """
    Retrieve a conversion mapping by ID.

    Args:
        db (Session): Database session.
        conv_id (int): Mapping ID.

    Returns:
        Optional[ItemConversionMap]: Mapping or None.
    """
    logger.debug(f"Retrieving conversion id={conv_id}")
    return db.query(ItemConversionMap).filter(ItemConversionMap.id == conv_id).first()


def update_conversion(
    db: Session, conv_id: int, data: ItemConversionUpdate, updated_by: str
) -> Optional[ItemConversionMap]:
    """
    Update an existing conversion mapping.

    Args:
        db (Session): Database session.
        conv_id (int): Mapping ID.
        data (ItemConversionUpdate): Fields to update.
        updated_by (str): Updater ID.

    Returns:
        Optional[ItemConversionMap]: Updated mapping or None.
    """
    logger.info(f"Updating conversion id={conv_id}")
    conv = get_conversion(db, conv_id)
    if not conv:
        logger.error(f"Conversion not found id={conv_id}")
        return None
    for field, val in data.dict(exclude_unset=True).items():
        setattr(conv, field, val)
    conv.updated_by = updated_by
    db.commit()
    db.refresh(conv)
    logger.debug(f"Conversion id={conv_id} updated")
    return conv


def delete_conversion(db: Session, conv_id: int) -> bool:
    """
    Delete a conversion mapping by ID.

    Args:
        db (Session): Database session.
        conv_id (int): Mapping ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting conversion id={conv_id}")
    conv = get_conversion(db, conv_id)
    if not conv:
        logger.error(f"Conversion not found id={conv_id}")
        return False
    db.delete(conv)
    db.commit()
    logger.debug(f"Conversion id={conv_id} deleted")
    return True
