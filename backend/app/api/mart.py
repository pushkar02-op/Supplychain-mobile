from typing import List

from app.db.schemas.mart import MartCreate, MartRead
from app.db.session import get_db
from app.services.mart import create_mart, get_marts_by_company
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter(prefix="/marts", tags=["Marts"])


@router.post("/", response_model=MartRead)
def create(mart: MartCreate, db: Session = Depends(get_db)):
    return create_mart(db, mart)


@router.get("/company/{company_name}", response_model=List[MartRead])
def list_by_company(company_name: str, db: Session = Depends(get_db)):
    return get_marts_by_company(db, company_name)
