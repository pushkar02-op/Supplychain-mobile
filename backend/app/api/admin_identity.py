from typing import List

from app.db.models.mart import Mart

# from app.api import deps # Circular import fixed
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.mart_item_alias import MartItemAlias
from app.db.schemas.mart_bill_item import (
    UnresolvedMartBillItemRead as UnresolvedInvoiceItemRead,
)
from app.db.schemas.mart_item_alias import (
    MartItemAliasCreate,
    MartItemAliasRead,
    ResolutionRequest,
)
from app.db.session import get_db
from app.services.item_alias import resolve_item_for_mart
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

router = APIRouter()


@router.get("/invoices/unresolved", response_model=List[UnresolvedInvoiceItemRead])
def get_unresolved_invoice_items(
    db: Session = Depends(get_db),
    # current_user: models.User = Depends(deps.get_current_active_admin), # Assuming auth
):
    """
    List all invoice items that haven't been mapped to a canonical Item.
    """
    items = db.query(MartBillItem).filter(MartBillItem.item_id.is_(None)).all()
    return items


@router.post("/aliases", response_model=MartItemAliasRead)
def create_mart_alias(
    alias_in: MartItemAliasCreate,
    db: Session = Depends(get_db),
    # current_user: models.User = Depends(deps.get_current_active_admin),
):
    """
    Create a Mart-Scoped Alias to map external names/codes to a canonical Item.
    """
    # Check if mart exists
    mart = db.query(Mart).filter(Mart.id == alias_in.mart_id).first()
    if not mart:
        raise HTTPException(status_code=404, detail="Mart not found")

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
        raise HTTPException(
            status_code=400, detail="Alias with this name already exists for this Mart"
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
    db: Session = Depends(get_db),
):
    """
    Trigger re-resolution for unresolved items of a specific Mart.
    """
    from app.db.models.mart_bill import MartBill

    unresolved = (
        db.query(MartBillItem)
        .join(MartBill)
        .filter(MartBill.mart_id == request.mart_id, MartBillItem.item_id.is_(None))
        .all()
    )

    resolved_count = 0
    for item in unresolved:
        resolved = resolve_item_for_mart(
            db, mart_id=request.mart_id, code=item.item_code, name=item.item_name
        )
        if resolved:
            item.item_id = resolved.id
            resolved_count += 1

    db.commit()

    return {
        "resolved_count": resolved_count,
        "remaining": len(unresolved) - resolved_count,
    }
