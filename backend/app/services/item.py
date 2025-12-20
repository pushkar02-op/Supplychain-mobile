"""
Service functions for item management.
Handles CRUD operations for catalog items and queries on stock availability.
"""

import logging
from typing import List, Optional

from app.db.models import Item
from app.db.models.batch import Batch
from app.db.models.uom import UOM
from app.db.schemas.item import ItemCreate, ItemRead, ItemUpdate
from sqlalchemy import select
from sqlalchemy.orm import Session

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
    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    new_item = Item(
        name=entry.name,
        default_unit=entry.default_unit,
        created_by=user_name,
        created_by_id=user_id,
        updated_by=user_name,
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
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        return None
    uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
    item_data = ItemRead.from_orm(item)
    item_data.default_unit = uom.code if uom else None
    return item_data


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
    from app.utils.pagination import get_pagination_params

    offset, limit = get_pagination_params(skip=skip, limit=limit)

    items = db.query(Item).offset(offset).limit(limit).all()
    uoms = {u.id: u.code for u in db.query(UOM).all()}
    result = []
    for item in items:
        item_data = ItemRead.from_orm(item)
        item_data.default_unit = uoms.get(item.default_uom_id)
        result.append(item_data)
    return result


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
    items = db.query(Item).filter(Item.id.in_(select(subq.c.item_id))).all()
    uoms = {u.id: u.code for u in db.query(UOM).all()}
    result = []
    for item in items:
        item_data = ItemRead.from_orm(item)
        item_data.default_unit = uoms.get(item.default_uom_id)
        result.append(item_data)
    return result


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

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, updated_by)

    item.updated_by = user_name
    # item.updated_by_id = user_id # If we had it, but we only promised created_by_id for now?
    # The migration added created_by_id, but AuditMixin has updated_by.
    # Did we add updated_by_id?
    # MIGRATION_DESIGN_CREATED_BY.md: "Add a new column created_by_id"
    # It did NOT mention updated_by_id.
    # So we ONLY update created_by_id on CREATE? No, created_by is immutable?
    # Actually updated_by is usually just string.
    # Let's keep updated_by as is (resolved username) and NOT try to set updated_by_id since it doesn't exist.
    db.commit()
    db.refresh(item)
    uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
    item_data = ItemRead.from_orm(item)
    item_data.default_unit = uom.code if uom else None
    return item_data


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
