"""
Service functions for item management.
Handles CRUD operations for catalog items and queries on stock availability.
"""

import logging
from typing import List, Optional

from app.db.models import Item
from app.db.models.batch import Batch
from app.db.models.item import ItemStatus
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

    # Check duplicate
    existing = db.query(Item).filter(Item.name == entry.name).first()
    if existing:
        from app.core.exceptions import AppException

        # raise 409 so client knows it exists (E2E script handles this by fetching)
        logger.warning(f"Item '{entry.name}' already exists")
        raise AppException(
            f"Item with name '{entry.name}' already exists", status_code=409
        )

    # Resolve UOM
    uom_id = None
    if entry.default_unit:
        from sqlalchemy import func

        # Case-insensitive lookup
        uom = (
            db.query(UOM)
            .filter(func.lower(UOM.code) == entry.default_unit.strip().lower())
            .first()
        )
        if not uom:
            from app.core.exceptions import AppException

            raise AppException(
                f"Invalid UOM code: {entry.default_unit}", status_code=400
            )
        uom_id = uom.id

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    new_item = Item(
        name=entry.name,
        item_code=entry.item_code,
        default_uom_id=uom_id,
        creation_intent=entry.creation_intent,
        created_by=user_name,
        created_by_id=user_id,
        updated_by=user_name,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)

    # Return valid read model
    item_data = ItemRead.from_orm(new_item)
    item_data.default_unit = entry.default_unit
    logger.debug(f"Created item id={new_item.id}")
    return item_data


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


def get_all_items(
    db: Session, skip: int = 0, limit: int = 100, include_inactive: bool = False
) -> List[Item]:
    """
    Retrieve all catalog items with pagination.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.
        include_inactive (bool): If True, include INACTIVE items. Default: False (ACTIVE only).

    Returns:
        List[Item]: List of items.
    """
    logger.debug(
        f"Fetching items skip={skip}, limit={limit}, include_inactive={include_inactive}"
    )
    from app.utils.pagination import get_pagination_params

    offset, limit = get_pagination_params(skip=skip, limit=limit)

    query = db.query(Item)
    if not include_inactive:
        query = query.filter(Item.status == ItemStatus.ACTIVE)

    items = query.offset(offset).limit(limit).all()
    uoms = {u.id: u.code for u in db.query(UOM).all()}
    result = []
    for item in items:
        item_data = ItemRead.from_orm(item)
        item_data.default_unit = uoms.get(item.default_uom_id)
        result.append(item_data)
    return result


def search_advisory_name_matches(
    db: Session, name: str, uom_code: Optional[str] = None, limit: int = 5
) -> List[dict]:
    """
    Find similar items for "Duplicate Awareness" (Advisory Only).

    Constraints:
    - READ-ONLY
    - Name-only + base UOM matching
    - NO alias-based inference
    - NO fuzzy/trigram logic (Deterministic containment only)
    """
    from app.db.models.item_alias import ItemAlias
    from app.db.models.stock_entry import StockEntry
    from sqlalchemy import func

    query = db.query(Item)

    # 1. Name Check (Simple containment for now, ILIKE)
    # Split tokens? "Token overlap".
    # e.g. "Green Apple" vs "Apple Green".
    tokens = name.strip().split()
    if tokens:
        # Match if ANY token is in the name? Or ALL?
        # "Similarity" implies strictness.
        # Let's match ANY token > 3 chars? too loose.
        # Let's do simple ILIKE %name% first.
        query = query.filter(Item.name.ilike(f"%{name.strip()}%"))

    # 2. UOM Check (if provided, prioritize or filter? Requirement says "Same base UOM" in display logic)
    # "Perform simple similarity checks: ... Same base UOM".
    # Usually this means "Find Name Match" AND "UOM Match".
    # But if names match but UOM differs, is it a duplicate? Maybe.
    # If UOM matches but name differs? No.
    # So Name is primary filter.
    if uom_code:
        uom = db.query(UOM).filter(func.lower(UOM.code) == uom_code.lower()).first()
        if uom:
            # We want to flag if existing item ALSO has this UOM?
            # Or assume UOM mismatch is safer?
            # "Return list... For each candidate show... Base UOM"
            pass  # We return everything matching name, UI shows details.

    candidates = query.limit(limit).all()

    results = []
    uom_cache = {u.id: u.code for u in db.query(UOM).all()}

    for item in candidates:
        # Alias count
        alias_count = (
            db.query(ItemAlias).filter(ItemAlias.master_item_id == item.id).count()
        )
        # Usage
        has_stock = db.query(StockEntry).filter(StockEntry.item_id == item.id).first()

        results.append(
            {
                "id": item.id,
                "name": item.name,
                "default_unit": uom_cache.get(item.default_uom_id),
                "alias_count": alias_count,
                "has_stock": bool(has_stock),
            }
        )

    return results


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

    update_data = entry_update.dict(exclude_unset=True)

    # Handle UOM Change (MDU-002)
    if "default_unit" in update_data:
        new_unit = update_data.pop("default_unit")

        # 1. Resolve UOM
        from sqlalchemy import func

        uom = (
            db.query(UOM)
            .filter(func.lower(UOM.code) == new_unit.strip().lower())
            .first()
        )
        if not uom:
            from app.core.exceptions import AppException

            raise AppException(f"Invalid UOM code: {new_unit}", status_code=400)

        # 2. Check if changing (idempotency)
        if uom.id != item.default_uom_id:
            # 3. Enforce MDU-002: No change if inventory exists
            from app.core.exceptions import AppException
            from app.db.models.inventory_txn import InventoryTxn

            has_history = (
                db.query(InventoryTxn).filter(InventoryTxn.item_id == item.id).first()
            )
            if has_history:
                raise AppException(
                    "Cannot change default UOM after inventory transactions exist.",
                    status_code=409,
                    extra={"rule_id": "MDU-002"},
                )

            item.default_uom_id = uom.id

    for field, val in update_data.items():
        setattr(item, field, val)

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, updated_by)

    item.updated_by = user_name
    # item.updated_by_id = user_id
    db.commit()
    db.refresh(item)
    uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
    item_data = ItemRead.from_orm(item)
    item_data.default_unit = uom.code if uom else None
    return item_data


def deactivate_item(db: Session, item_id: int) -> Item | None:
    """
    Deactivate an item (set status to INACTIVE).

    This is reversible via reactivate_item. Preserves all data and relationships.
    Idempotent: calling on already-inactive item returns success.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        Item | None: Updated item if found, None otherwise.
    """

    logger.info(f"Deactivating item id={item_id}")
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        logger.error(f"Item not found id={item_id}")
        return None

    item.status = ItemStatus.INACTIVE
    db.commit()
    db.refresh(item)
    logger.info(f"Item id={item_id} deactivated")
    return item


def reactivate_item(db: Session, item_id: int) -> Item | None:
    """
    Reactivate an item (set status to ACTIVE).

    Idempotent: calling on already-active item returns success.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.

    Returns:
        Item | None: Updated item if found, None otherwise.
    """

    logger.info(f"Reactivating item id={item_id}")
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        logger.error(f"Item not found id={item_id}")
        return None

    item.status = ItemStatus.ACTIVE
    db.commit()
    db.refresh(item)
    logger.info(f"Item id={item_id} reactivated")
    return item
