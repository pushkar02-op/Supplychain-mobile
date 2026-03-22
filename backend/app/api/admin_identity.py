from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.mart_item_alias import (
    MartItemAliasCreate,
    MartItemAliasRead,
    ResolutionRequest,
)
from app.db.session import get_db
from app.services import admin_identity as svc
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter()


@router.post("/aliases", response_model=MartItemAliasRead)
def create_mart_alias(
    alias_in: MartItemAliasCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    Create a Mart-Scoped Alias to map external names/codes to a canonical Item.
    """
    return svc.create_mart_alias(
        db=db,
        alias_in=alias_in,
        current_user_name=current_user.username,
    )


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
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    return svc.resolve_invoice_items(
        db=db,
        mart_id=request.mart_id,
        warehouse_id=resolved_warehouse_id,
    )
