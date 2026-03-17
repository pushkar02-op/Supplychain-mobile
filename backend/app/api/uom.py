import logging
from typing import List

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.uom import UOMCreate, UOMRead, UOMUpdate
from app.db.session import get_db
from app.services.uom import create_uom, list_uoms, update_uom
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/uom", tags=["UOM"])


@router.post("/", response_model=UOMRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: UOMCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> UOMRead:
    return create_uom(db, entry)


@router.get("/", response_model=List[UOMRead], summary="List UOMs")
def read_all(
    include_inactive: bool = Query(False),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
) -> List[UOMRead]:
    results = list_uoms(db, include_inactive=include_inactive)
    return results[skip : skip + limit]


@router.put("/{uom_id}", response_model=UOMRead)
def update(
    uom_id: int,
    entry: UOMUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> UOMRead:
    return update_uom(db, uom_id, entry)
