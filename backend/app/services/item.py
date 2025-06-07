"""
Service functions for item management.
Handles CRUD operations for catalog items and queries on stock availability.
"""

import logging
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import AppException
from app.db.models import Item
from app.db.models.batch import Batch
from app.db.schemas.item import ItemCreate, ItemUpdate

logger = logging.getLogger(__name__)


def create_item(db: Session, entry: ItemCreate, created_by: int) -> Item:
    """
    Create a new catalog item.

    Args:
        db (Session): Database session.
        entry (ItemCreate): New item data.
        created_by (int): Creator ID.

    Returns:
        Item: Created item.
    """
    logger.info(f"Creating item '{entry.name}'")
    new_item = Item(
        name=entry.name, default_unit=entry.default_unit, created_by=created_by
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    logger.debug(f"Created item id={new_item.id}")
    return new_item


def get_item(db: Session, item_id: int) -> Optional[Item]:
    """
    Retrieve a catalog item by ID.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        Optional[Item]: The item or None.
    """
    logger.debug(f"Retrieving item id={item_id}")
    return db.query(Item).filter(Item.id == item_id).first()


def get_all_items(db: Session, skip: int = 0, limit: int = 100) -> List[Item]:
    """
    Retrieve all catalog items with pagination.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.

    Returns:
        List[Item]: List of items.
    """
    logger.debug(f"Fetching items skip={skip}, limit={limit}")
    return db.query(Item).offset(skip).limit(limit).all()


def get_items_with_available_batches(db: Session) -> List[Item]:
    """
    Retrieve items that have at least one batch with positive quantity.

    Args:
        db (Session): Database session.

    Returns:
        List[Item]: Items in stock.
    """
    logger.debug("Fetching items with available batches")
    subq = select(Batch.item_id).where(Batch.quantity > 0).distinct().subquery()
    return db.query(Item).filter(Item.id.in_(select(subq.c.item_id))).all()


def update_item(
    db: Session, item_id: int, entry_update: ItemUpdate, updated_by: int
) -> Optional[Item]:
    """
    Update a catalog item's fields.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.
        entry_update (ItemUpdate): Fields to update.
        updated_by (int): Updater ID.

    Returns:
        Optional[Item]: Updated item or None.
    """
    logger.info(f"Updating item id={item_id}")
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        logger.error(f"Item not found id={item_id}")
        return None

    for field, val in entry_update.dict(exclude_unset=True).items():
        setattr(item, field, val)
    item.updated_by = updated_by
    db.commit()
    db.refresh(item)
    logger.debug(f"Item id={item_id} updated")
    return item


def delete_item(db: Session, item_id: int) -> bool:
    """
    Delete a catalog item.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting item id={item_id}")
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        logger.error(f"Item not found id={item_id}")
        return False
    db.delete(item)
    db.commit()
    logger.debug(f"Item id={item_id} deleted")
    return True
