from typing import List, Optional

from app.db.models.item_alias import ItemAlias
from app.db.schemas.item_alias import ItemAliasCreate
from sqlalchemy.orm import Session


def create_alias(db: Session, data: ItemAliasCreate, created_by: str) -> ItemAlias:
    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    alias = ItemAlias(
        **data.dict(), created_by=user_name, created_by_id=user_id, updated_by=user_name
    )
    db.add(alias)
    db.commit()
    db.refresh(alias)
    return alias


def get_all_aliases(db: Session) -> List[ItemAlias]:
    return db.query(ItemAlias).all()


def get_alias_by_code_or_name(db: Session, code: str, name: str) -> Optional[ItemAlias]:
    return (
        db.query(ItemAlias)
        .filter((ItemAlias.alias_code == code) | (ItemAlias.alias_name.ilike(name)))
        .first()
    )
