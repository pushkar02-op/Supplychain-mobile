"""
Service functions for master item management.
Handles CRUD for master items, aliases, conversions, and mapping of unmapped items.
"""

import logging
from collections import defaultdict
from typing import List, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from app.core.exceptions import AppException
from app.db.models import Item, ItemAlias, ItemConversionMap, InvoiceItem, UOM, User
from app.db.schemas.item_management import (
    ItemManagementCreateUpdate,
    ItemManagementRead,
)

logger = logging.getLogger(__name__)


def get_master_items_details(db: Session) -> List[ItemManagementRead]:
    """
    Fetches all master items with their related aliases, conversions, and default UOM.
    Uses eager loading to prevent N+1 queries.
    """
    items = (
        db.query(Item)
        .options(
            selectinload(Item.aliases),
            selectinload(Item.default_uom),
        )
        .order_by(Item.name)
        .all()
    )

    if not items:
        return []

    item_ids = [item.id for item in items]

    # Eagerly load all conversions for the fetched items in a separate query
    all_conversions = (
        db.query(ItemConversionMap)
        .filter(ItemConversionMap.item_id.in_(item_ids))
        .all()
    )

    # Group conversions by item_id for efficient lookup
    conversions_by_item_id = defaultdict(list)
    for conv in all_conversions:
        conversions_by_item_id[conv.item_id].append(conv)

    return [
        ItemManagementRead(
            id=item.id,
            name=item.name,
            default_uom_code=item.default_uom.code if item.default_uom else None,
            aliases=item.aliases,
            conversions=conversions_by_item_id.get(item.id, []),
        )
        for item in items
    ]


def get_unmapped_invoice_items_with_suggestions(db: Session) -> List[dict]:
    """
    Returns a list of invoice items that are not mapped to any master Item.
    For each unmapped item, it provides a list of potential mapping suggestions.
    """
    unmapped_items = db.query(InvoiceItem).filter(InvoiceItem.item_id.is_(None)).all()
    uoms = {u.id: u.code for u in db.query(UOM).all()}
    results = []

    # NOTE: This section has a potential N+1 query problem. For a large number of
    # unmapped items, this will run one query per item. For production, consider
    # a more advanced full-text search solution or a more complex single query.
    for row in unmapped_items:
        suggestions = (
            db.query(Item)
            .filter(
                or_(
                    Item.name.ilike(f"%{row.item_name}%"),
                    Item.item_code.ilike(f"%{row.item_code}%"),
                )
            )
            .limit(10)
            .all()
        )
        results.append(
            {
                "invoice_item_id": row.id,
                "item_code": row.item_code,
                "item_name": row.item_name,
                "uom": row.uom,
                "invoice_id": row.invoice_id,
                "store_name": row.store_name,
                "invoice_date": row.invoice_date.isoformat(),
                "suggested_items": [
                    {
                        "id": s.id,
                        "name": s.name,
                        "item_code": s.item_code,
                        "uom": uoms.get(s.default_uom_id),
                    }
                    for s in suggestions
                ],
            }
        )
    return results


def create_or_update_master_item(
    db: Session, payload: ItemManagementCreateUpdate, current_user: User
) -> Item:
    """Creates or updates a master item and its associated aliases and conversions."""
    if payload.id:
        item = db.get(Item, payload.id)
        if not item:
            raise AppException("Item not found", status_code=404)
        item.name = payload.name
        item.default_uom_id = payload.default_uom_id
        item.updated_by = current_user.username
    else:
        item = Item(
            name=payload.name,
            default_uom_id=payload.default_uom_id,
            created_by=current_user.username,
            updated_by=current_user.username,
        )
        db.add(item)
        db.flush()  # Get the item.id before commit

    # --- Manage Aliases ---
    # Unlink old aliases that are not in the payload
    db.query(ItemAlias).filter(
        ItemAlias.master_item_id == item.id,
        ~ItemAlias.id.in_([a.id for a in payload.aliases if a.id]),
    ).update({"master_item_id": None}, synchronize_session=False)

    # Add or update new aliases
    for alias_data in payload.aliases:
        if alias_data.id:
            db_alias = db.get(ItemAlias, alias_data.id)
            if db_alias:
                # It's an existing ItemAlias, just link it to our item.
                db_alias.master_item_id = item.id
            else:
                # It's not an existing ItemAlias. Let's assume it's an InvoiceItem ID.
                # We should create a new ItemAlias from it.
                invoice_item = db.get(InvoiceItem, alias_data.id)
                if invoice_item:
                    # Link the original invoice item to the master item for consistency.
                    invoice_item.item_id = item.id

                    # To prevent creating duplicate aliases, check if one with the same name/code already exists.
                    existing_alias_by_name = (
                        db.query(ItemAlias)
                        .filter(
                            ItemAlias.alias_code == invoice_item.item_code,
                            ItemAlias.alias_name == invoice_item.item_name,
                        )
                        .first()
                    )

                    if existing_alias_by_name:
                        # An alias with these details already exists. Just link it to our item.
                        existing_alias_by_name.master_item_id = item.id
                    else:
                        # Create a brand new alias record.
                        new_alias = ItemAlias(
                            master_item_id=item.id,
                            alias_code=invoice_item.item_code,
                            alias_name=invoice_item.item_name,
                            created_by=current_user.username,
                        )
                        db.add(new_alias)

    # --- Manage Conversions (simple delete and recreate) ---
    db.query(ItemConversionMap).filter(ItemConversionMap.item_id == item.id).delete(
        synchronize_session=False
    )
    for conv_data in payload.conversions:
        db.add(
            ItemConversionMap(
                item_id=item.id,
                source_unit=conv_data.source_unit,
                target_unit=conv_data.target_unit,
                conversion_factor=conv_data.conversion_factor,
                created_by=current_user.username,
            )
        )

    db.commit()
    db.refresh(item)
    return item
