# backend/app/api/item_management.py

from typing import List

from app.core.auth import get_current_user
from app.db.models import UOM, Item, ItemAlias, User
from app.db.models.mart_bill_item import MartBillItem as InvoiceItem
from app.db.schemas.item_management import (
    AliasMapInput,
    ItemManagementCreateUpdate,
    ItemManagementRead,
    UOMRead,
)
from app.db.session import get_db
from app.services import item_management as svc
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

router = APIRouter(prefix="/item-management", tags=["Item Management"])


class InvoiceItemMapInput(BaseModel):
    invoice_item_id: int
    master_item_id: int


@router.get("/", response_model=List[ItemManagementRead])
def get_items(db: Session = Depends(get_db)):
    return svc.get_master_items_details(db)


@router.get("/uoms", response_model=List[UOMRead])
def get_uoms(db: Session = Depends(get_db)):
    return db.query(UOM).order_by(UOM.code).all()


@router.get("/unmapped-invoice-items", summary="Fetch unmapped invoice items")
def fetchUnmappedInvoiceItems(db: Session = Depends(get_db)) -> List[dict]:
    return svc.get_unmapped_invoice_items_with_suggestions(db)


@router.post("/", response_model=ItemManagementRead)
def create_or_update_item(
    payload: ItemManagementCreateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ItemManagementRead:
    item = svc.create_or_update_master_item(db, payload, current_user)
    # We can leverage the existing get_master_items_details to return the full object,
    # but that would be inefficient. A direct construction is better.
    return ItemManagementRead.from_orm(item)


@router.post("/map-alias")
def map_alias_to_item(payload: AliasMapInput, db: Session = Depends(get_db)):
    alias = db.query(ItemAlias).filter(ItemAlias.id == payload.alias_id).first()
    if not alias:
        raise HTTPException(status_code=404, detail="Alias not found")
    alias.master_item_id = payload.item_id
    db.commit()
    return {"message": "Alias mapped successfully"}


@router.post(
    "/map-invoice-item", summary="Map an unmapped invoice item to a master item"
)
def map_invoice_item(
    payload: InvoiceItemMapInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    invoice_item = db.get(InvoiceItem, payload.invoice_item_id)
    if not invoice_item:
        raise HTTPException(status_code=404, detail="Invoice item not found")
    if invoice_item.item_id:
        raise HTTPException(
            status_code=400, detail="This invoice item is already mapped."
        )

    master_item = db.get(Item, payload.master_item_id)
    if not master_item:
        raise HTTPException(status_code=404, detail="Master item not found")

    # 1. Map the invoice item
    invoice_item.item_id = payload.master_item_id

    # 2. Create an alias for future auto-mapping
    existing_alias = (
        db.query(ItemAlias)
        .filter_by(alias_code=invoice_item.item_code, alias_name=invoice_item.item_name)
        .first()
    )
    if not existing_alias:
        new_alias = ItemAlias(
            master_item_id=payload.master_item_id,
            alias_code=invoice_item.item_code,
            alias_name=invoice_item.item_name,
            created_by=current_user.username,
        )
        db.add(new_alias)

    db.commit()
    return {"message": "Invoice item mapped and alias created successfully"}
