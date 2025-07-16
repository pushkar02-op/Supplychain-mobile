from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.schemas.company import CompanyCreate, CompanyRead
from app.services.company import create_company, get_companies
from typing import List

router = APIRouter(prefix="/companies", tags=["Companies"])


@router.post("/", response_model=CompanyRead)
def create(company: CompanyCreate, db: Session = Depends(get_db)):
    return create_company(db, company)


@router.get("/", response_model=List[CompanyRead])
def list_all(db: Session = Depends(get_db)):
    return get_companies(db)
