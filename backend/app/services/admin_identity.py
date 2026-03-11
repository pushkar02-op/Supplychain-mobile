"""
Service functions for admin identity operations.
Handles mart alias creation and invoice item resolution.
"""

import logging

from app.core.exceptions import AppException
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.mart_item_alias import MartItemAlias
from app.db.schemas.mart_item_alias import MartItemAliasCreate
from app.services.alias_resolver import resolve_alias
from app.services.audit import log_action
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_mart_alias(
    db: Session,
    alias_in: MartItemAliasCreate,
    current_user_name: str,
) -> MartItemAlias:
    """
    Create a Mart-Scoped Alias to map external names/codes to a canonical Item.
    """
    # Check if mart exists
    mart = db.query(Mart).filter(Mart.id == alias_in.mart_id).first()
    if not mart:
        raise AppException(
            detail="Mart not found", status_code=404, rule_id=None, metadata={}
        )

    # Constraint Check happens at DB level, but we can pre-check
    existing = (
        db.query(MartItemAlias)
        .filter(
            MartItemAlias.mart_id == alias_in.mart_id,
            MartItemAlias.alias_name == alias_in.alias_name,
        )
        .first()
    )
    if existing:
        raise AppException(
            detail="Alias with this name already exists for this Mart",
            status_code=400,
            rule_id=None,
            metadata={},
        )

    db_obj = MartItemAlias(
        mart_id=alias_in.mart_id,
        item_id=alias_in.item_id,
        alias_code=alias_in.alias_code,
        alias_name=alias_in.alias_name,
        created_by=current_user_name,
    )
    db.add(db_obj)

    try:
        log_action(
            db=db,
            actor_user_id=None,
            action_type="mart_alias_created",
            entity_type="mart_item_alias",
            entity_id=db_obj.id,
            metadata={
                "mart_id": alias_in.mart_id,
                "alias_name": alias_in.alias_name,
            },
        )
    except Exception:
        logger.warning("Audit log failed for mart_alias_created", exc_info=True)

    db.commit()
    db.refresh(db_obj)
    return db_obj


def resolve_invoice_items(
    db: Session,
    mart_id: int,
    warehouse_id: int,
) -> dict:
    """
    Trigger re-resolution for unresolved items of a specific Mart.
    Matches unresolved MartBillItems to MartItemAliases by code or name.
    """
    unresolved = (
        db.query(MartBillItem)
        .join(MartBill)
        .filter(
            MartBill.mart_id == mart_id,
            MartBill.warehouse_id == warehouse_id,
            MartBillItem.item_id.is_(None),
        )
        .all()
    )

    resolved_count = 0
    for item in unresolved:
        item_id = resolve_alias(
            db=db,
            mart_id=mart_id,
            item_code=item.item_code,
            item_name=item.item_name,
        )
        if item_id:
            item.item_id = item_id
            resolved_count += 1

    try:
        log_action(
            db=db,
            actor_user_id=None,
            action_type="invoice_items_resolved",
            entity_type="mart_bill_item",
            entity_id=None,
            metadata={
                "mart_id": mart_id,
                "warehouse_id": warehouse_id,
                "resolved_count": resolved_count,
                "remaining": len(unresolved) - resolved_count,
            },
        )
    except Exception:
        logger.warning("Audit log failed for invoice_items_resolved", exc_info=True)

    db.commit()

    return {
        "resolved_count": resolved_count,
        "remaining": len(unresolved) - resolved_count,
    }
