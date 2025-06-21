# app/db/seed/uom_seed.py

from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime

from app.db.models.item import Item
from app.db.models.item_alias import ItemAlias


def seed_aliases(db: Session, created_by: str = "system") -> None:
    aliases = [
        {
            "alias_name": "APPLE FUJI IMP USA (KG)",
            "alias_code": "590000001",
            "item_name": "APPLE FUJI",
        },
        {"alias_name": "Avocado", "alias_code": "590003579", "item_name": "AVACADO"},
        {
            "alias_name": "ONION ECONOMY (KG)",
            "alias_code": "590001600",
            "item_name": "ONION",
        },
    ]
    for a in aliases:
        item = (
            db.query(Item)
            .filter(func.lower(func.trim(Item.name)) == a["item_name"].strip().lower())
            .first()
        )

        if (
            item
            and not db.query(ItemAlias)
            .filter(
                func.lower(func.trim(ItemAlias.alias_name))
                == a["alias_name"].strip().lower(),
                ItemAlias.master_item_id == item.id,
            )
            .first()
        ):
            db.add(
                ItemAlias(
                    master_item_id=item.id,
                    alias_name=a["alias_name"].strip(),
                    alias_code=a["alias_code"].strip(),
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )
    db.commit()
