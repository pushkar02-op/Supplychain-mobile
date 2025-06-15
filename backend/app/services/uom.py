from sqlalchemy.orm import Session
from app.db.models.uom import UOM
from app.db.schemas.uom import UOMCreate, UOMRead


def create_uom(db: Session, data: UOMCreate) -> UOM:
    u = UOM(code=data.code, description=data.description)
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def list_uoms(db: Session) -> list[UOM]:
    return db.query(UOM).all()
