from app.core.exceptions import AppException
from app.db.models.uom import UOM
from app.db.schemas.uom import UOMCreate, UOMUpdate
from sqlalchemy.orm import Session


def create_uom(db: Session, data: UOMCreate) -> UOM:
    u = UOM(code=data.code, description=data.description, is_active=data.is_active)
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def list_uoms(db: Session, include_inactive: bool = False) -> list[UOM]:
    query = db.query(UOM)
    if not include_inactive:
        query = query.filter(UOM.is_active.is_(True))
    return query.order_by(UOM.code.asc()).all()


def update_uom(db: Session, uom_id: int, data: UOMUpdate) -> UOM:
    uom = db.query(UOM).filter(UOM.id == uom_id).first()
    if not uom:
        raise AppException(detail="UOM not found", status_code=404)

    uom.code = data.code
    uom.description = data.description
    uom.is_active = data.is_active
    db.commit()
    db.refresh(uom)
    return uom
