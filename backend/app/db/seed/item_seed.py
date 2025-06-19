# app/db/seed/item_seed.py

from sqlalchemy.orm import Session
from app.db.models.item import Item
from app.db.models.uom import UOM
from datetime import datetime


def seed_items(db: Session, created_by: str = "system") -> None:
    item_data = [
        {"name": "Apple Fuji", "item_code": "590000001", "default_uom": "KG"},
        {"name": "Avocado", "item_code": "590003579", "default_uom": "EA"},
    ]

    for item in item_data:
        uom = db.query(UOM).filter_by(code=item["default_uom"]).first()
        if not uom:
            continue
        exists = db.query(Item).filter_by(name=item["name"]).first()
        if not exists:
            db.add(
                Item(
                    name=item["name"],
                    default_uom_id=uom.id,
                    item_code=item["item_code"],
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )
    db.commit()
