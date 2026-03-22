# backend/app/api/item_management.py

from typing import List

from app.core.auth import get_current_user, require_role
from app.db.enums.role import Role
from app.db.models import UOM, User
from app.db.schemas.item_management import (
    AliasMapInput,
    BatchMapInvoiceItemsRequest,
    ItemManagementCreateUpdate,
    ItemManagementRead,
    UOMRead,
)
from app.db.session import get_db
from app.services import item_management as svc
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

router = APIRouter(prefix="/item-management", tags=["Item Management"])


class InvoiceItemMapInput(BaseModel):
    invoice_item_id: int
    master_item_id: int


@router.get("/", response_model=List[ItemManagementRead])
def get_items(
    search: str | None = Query(None, description="Filter items by name"),
    include_inactive: bool = False,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
):
    results = svc.get_master_items_details(
        db, include_inactive=include_inactive, search=search
    )
    return results[skip : skip + limit]


@router.get("/uoms", response_model=List[UOMRead])
def get_uoms(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
):
    results = db.query(UOM).order_by(UOM.code).all()
    return results[skip : skip + limit]


@router.get("/unmapped-invoice-items", summary="Fetch unmapped invoice items")
def fetchUnmappedInvoiceItems(
    warehouse_id: int | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> List[dict]:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="read",
    )
    results = svc.get_unmapped_invoice_items_with_suggestions(
        db, warehouse_id=resolved_warehouse_id
    )
    return results[skip : skip + limit]


@router.post("/", response_model=ItemManagementRead)
def create_or_update_item(
    payload: ItemManagementCreateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> ItemManagementRead:
    item = svc.create_or_update_master_item(db, payload, current_user)
    # We can leverage the existing get_master_items_details to return the full object,
    # but that would be inefficient. A direct construction is better.
    return ItemManagementRead.from_orm(item)


@router.post("/map-alias")
def map_alias_to_item(
    payload: AliasMapInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
):
    return svc.map_alias_to_item(
        db=db,
        alias_id=payload.alias_id,
        item_id=payload.item_id,
    )


@router.post(
    "/batch-map-invoice-items",
    summary="Batch map invoice items to different master items",
)
def batch_map_invoice_items(
    payload: BatchMapInvoiceItemsRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
):
    return svc.batch_map_invoice_items(
        db=db,
        mappings=[m.dict() for m in payload.mappings],
        username=current_user.username,
    )


@router.post(
    "/map-invoice-item", summary="Map an unmapped invoice item to a master item"
)
def map_invoice_item(
    payload: InvoiceItemMapInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
):
    return svc.map_invoice_item(
        db=db,
        invoice_item_id=payload.invoice_item_id,
        master_item_id=payload.master_item_id,
        username=current_user.username,
    )
