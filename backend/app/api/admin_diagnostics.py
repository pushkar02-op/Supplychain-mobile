import logging

from app.core.auth import get_current_user
from app.db.models.user import User
from app.db.session import get_db
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/diagnostics/uom/missing-default", status_code=200)
def get_items_missing_default_uom(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    List items that have no default UOM configured.
    These items will fail basic inventory operations.
    """
    if not current_user.is_admin:
        from fastapi import HTTPException

        raise HTTPException(status_code=403, detail="Not authorized")

    result = db.execute(
        text("SELECT id, name, item_code FROM item WHERE default_uom_id IS NULL")
    )
    items = [
        {"id": row.id, "name": row.name, "item_code": row.item_code} for row in result
    ]

    return {"count": len(items), "items": items}
