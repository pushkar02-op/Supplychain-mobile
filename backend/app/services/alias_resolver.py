from typing import Optional

from app.db.models.item_alias import ItemAlias
from app.db.models.mart_item_alias import MartItemAlias
from sqlalchemy.orm import Session


def resolve_alias(
    db: Session,
    mart_id: int,
    item_code: Optional[str],
    item_name: Optional[str],
) -> Optional[int]:
    if item_code:
        mart_code_alias = (
            db.query(MartItemAlias)
            .filter(
                MartItemAlias.mart_id == mart_id,
                MartItemAlias.alias_code == item_code,
            )
            .first()
        )
        if mart_code_alias:
            return mart_code_alias.item_id

    if item_name:
        mart_name_alias = (
            db.query(MartItemAlias)
            .filter(
                MartItemAlias.mart_id == mart_id,
                MartItemAlias.alias_name.ilike(item_name),
            )
            .first()
        )
        if mart_name_alias:
            return mart_name_alias.item_id

    if item_code:
        item_code_alias = (
            db.query(ItemAlias).filter(ItemAlias.alias_code == item_code).first()
        )
        if item_code_alias:
            return item_code_alias.master_item_id

    if item_name:
        item_name_alias = (
            db.query(ItemAlias).filter(ItemAlias.alias_name.ilike(item_name)).first()
        )
        if item_name_alias:
            return item_name_alias.master_item_id

    return None
