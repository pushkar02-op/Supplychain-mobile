import logging

from app.core.auth import get_current_active_admin
from app.db.models.item import Item
from app.db.models.user import User
from app.db.session import get_db
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/diagnostics/uom/missing-default", status_code=200)
def get_items_missing_default_uom(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin),
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

    return {"count": len(result), "items": result}
