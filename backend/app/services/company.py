from sqlalchemy.orm import Session
from app.db.models.company import Company
from app.db.schemas.company import CompanyCreate


def create_company(db: Session, company: CompanyCreate) -> Company:
    db_company = Company(**company.dict())
    db.add(db_company)
    db.commit()
    db.refresh(db_company)
    return db_company


def get_companies(db: Session):
    return db.query(Company).all()
