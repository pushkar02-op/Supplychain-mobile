import logging
from typing import List

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.uom import UOMCreate, UOMRead
from app.db.session import get_db
from app.services.uom import create_uom, list_uoms
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/uom", tags=["UOM"])


@router.post("/", response_model=UOMRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: UOMCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> UOMRead:
    return create_uom(db, entry)


@router.get("/", response_model=List[UOMRead], summary="List UOMs")
def read_all(db: Session = Depends(get_db)) -> List[UOMRead]:
    return list_uoms(db)
