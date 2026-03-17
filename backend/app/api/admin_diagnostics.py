import logging

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.item import Item
from app.db.models.user import User
from app.db.schemas.admin_read_models import MissingDefaultUomResponse
from app.db.session import get_db
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get(
    "/diagnostics/uom/missing-default",
    response_model=MissingDefaultUomResponse,
    status_code=200,
)
def get_items_missing_default_uom(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    """
    List items that have no default UOM configured.
    These items will fail basic inventory operations.
    """

    items = db.query(Item).filter(Item.default_uom_id.is_(None)).all()
    result = [
        {"id": item.id, "name": item.name, "item_code": item.item_code}
        for item in items
    ]
    paged = result[skip : skip + limit]
    return {"count": len(paged), "items": paged}
