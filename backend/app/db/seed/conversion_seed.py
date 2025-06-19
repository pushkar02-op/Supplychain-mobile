# app/db/seed/conversion_seed.py

from sqlalchemy.orm import Session
from app.db.models.item_conversion_map import ItemConversionMap
from app.db.models.item import Item
from datetime import datetime


def seed_conversions(db: Session, created_by: str = "system") -> None:
    conversions = [
        {
            "item_name": "Apple Fuji",
            "source_unit": "KG",
            "target_unit": "EA",
            "factor": 5.0,
        },
        {
            "item_name": "Avocado",
            "source_unit": "EA",
            "target_unit": "KG",
            "factor": 6.0,
        },
    ]
    for c in conversions:
        item = db.query(Item).filter_by(name=c["item_name"]).first()
        if (
            item
            and not db.query(ItemConversionMap)
            .filter_by(
                item_id=item.id,
                source_unit=c["source_unit"],
                target_unit=c["target_unit"],
            )
            .first()
        ):
            db.add(
                ItemConversionMap(
                    item_id=item.id,
                    source_unit=c["source_unit"],
                    target_unit=c["target_unit"],
                    conversion_factor=c["factor"],
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )

    db.commit()
