# app/db/seed/uom_seed.py

from sqlalchemy.orm import Session
from datetime import datetime

from app.db.models.item import Item
from app.db.models.item_alias import ItemAlias


def seed_aliases(db: Session, created_by: str = "system") -> None:
    aliases = [
        {
            "alias_name": "APPLE FUJI IMP USA (KG)",
            "alias_code": "590000001",
            "item_name": "Apple Fuji",
        },
        {"alias_name": "AVACADO", "alias_code": "590003579", "item_name": "Avocado"},
    ]
    for a in aliases:
        item = db.query(Item).filter_by(name=a["item_name"]).first()
        if (
            item
            and not db.query(ItemAlias)
            .filter_by(alias_name=a["alias_name"], master_item_id=item.id)
            .first()
        ):
            db.add(
                ItemAlias(
                    master_item_id=item.id,
                    alias_name=a["alias_name"],
                    alias_code=a["alias_code"],
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )
    db.commit()
