from sqlalchemy.orm import Session
from app.db.models.mart import Mart
from app.db.schemas.mart import MartCreate


def create_mart(db: Session, mart: MartCreate) -> Mart:
    db_mart = Mart(**mart.dict())
    db.add(db_mart)
    db.commit()
    db.refresh(db_mart)
    return db_mart


def get_marts_by_company(db: Session, company_id: int):
    return db.query(Mart).filter(Mart.company_id == company_id).all()
