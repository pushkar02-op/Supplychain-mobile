from typing import List

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.mart import MartCreate, MartRead, MartStatusUpdate, MartUpdate
from app.db.session import get_db
from app.services.mart import (
    create_mart,
    get_marts_by_company,
    list_marts,
    set_mart_status,
    update_mart,
)
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter(prefix="/marts", tags=["Marts"])


@router.post("/", response_model=MartRead)
def create(
    mart: MartCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
):
    return create_mart(db, mart)


@router.get("/", response_model=List[MartRead])
def list_all(
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    return list_marts(db, include_inactive=include_inactive)


@router.put("/{mart_id}", response_model=MartRead)
def update(
    mart_id: int,
    mart: MartUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    return update_mart(db, mart_id, mart)


@router.patch("/{mart_id}/status", response_model=MartRead)
def patch_status(
    mart_id: int,
    payload: MartStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
):
    return set_mart_status(db, mart_id, payload)


@router.get("/company/{company_name}", response_model=List[MartRead])
def list_by_company(company_name: str, db: Session = Depends(get_db)):
    return get_marts_by_company(db, company_name)
