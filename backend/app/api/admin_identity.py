from typing import List

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.mart import Mart
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.mart_item_alias import MartItemAlias
from app.db.models.user import User
from app.db.schemas.mart_bill_item import (
    UnresolvedMartBillItemRead as UnresolvedInvoiceItemRead,
)
from app.db.schemas.mart_item_alias import (
    MartItemAliasCreate,
    MartItemAliasRead,
    ResolutionRequest,
)
from app.db.session import get_db
from app.services.warehouse_scope import resolve_warehouse_for_request

# from app.services.item_alias import resolve_item_for_mart
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter()


@router.get("/invoices/unresolved", response_model=List[UnresolvedInvoiceItemRead])
def get_unresolved_invoice_items(
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    List all invoice items that haven't been mapped to a canonical Item.
    """
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    items = (
        db.query(MartBillItem)
        .filter(
            MartBillItem.item_id.is_(None),
            MartBillItem.warehouse_id == resolved_warehouse_id,
        )
        .all()
    )
    return items


@router.post("/aliases", response_model=MartItemAliasRead)
def create_mart_alias(
    alias_in: MartItemAliasCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
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
        created_by="admin",  # Replace with actual user
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj


@router.post("/resolve", response_model=dict)
def resolve_invoice_items(
    request: ResolutionRequest,
    warehouse_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Trigger re-resolution for unresolved items of a specific Mart.
    """
    from app.db.models.mart_bill import MartBill

    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    unresolved = (
        db.query(MartBillItem)
        .join(MartBill)
        .filter(
            MartBill.mart_id == request.mart_id,
            MartBill.warehouse_id == resolved_warehouse_id,
            MartBillItem.item_id.is_(None),
        )
        .all()
    )

    resolved_count = 0
    for item in unresolved:
        # Inline resolution logic (Code match > Name match)
        alias = None
        if item.item_code:
            alias = (
                db.query(MartItemAlias)
                .filter(
                    MartItemAlias.mart_id == request.mart_id,
                    MartItemAlias.alias_code == item.item_code,
                )
                .first()
            )

        if not alias and item.item_name:
            alias = (
                db.query(MartItemAlias)
                .filter(
                    MartItemAlias.mart_id == request.mart_id,
                    MartItemAlias.alias_name.ilike(item.item_name),
                )
                .first()
            )

        if alias and alias.item_id:
            item.item_id = alias.item_id
            resolved_count += 1

    db.commit()

    return {
        "resolved_count": resolved_count,
        "remaining": len(unresolved) - resolved_count,
    }
