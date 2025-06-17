import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

from app.db.schemas.uom import UOMCreate, UOMRead
from app.services.uom import create_uom, list_uoms
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/uom", tags=["UOM"])


@router.post("/", response_model=UOMRead, status_code=status.HTTP_201_CREATED)
def create(entry: UOMCreate, db: Session = Depends(get_db)) -> UOMRead:
    return create_uom(db, entry)


@router.get("/", response_model=List[UOMRead], summary="List UOMs")
def read_all(db: Session = Depends(get_db)) -> List[UOMRead]:
    return list_uoms(db)
