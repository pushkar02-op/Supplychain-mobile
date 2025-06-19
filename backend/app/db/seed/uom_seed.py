# app/db/seed/uom_seed.py

from sqlalchemy.orm import Session
from app.db.models.uom import UOM
from datetime import datetime


def seed_uoms(db: Session, created_by: str = "system") -> None:
    uoms = [
        {"code": "KG", "description": "Kilogram"},
        {"code": "EA", "description": "Each"},
    ]

    for uom_data in uoms:
        exists = db.query(UOM).filter_by(code=uom_data["code"]).first()
        if not exists:
            db.add(
                UOM(
                    code=uom_data["code"],
                    description=uom_data["description"],
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )
    db.commit()
