# app/db/seed/seed_all.py

from sqlalchemy.orm import Session
from app.db.seed.uom_seed import seed_uoms
from app.db.seed.item_seed import seed_items
from app.db.seed.alias_seed import seed_aliases
from app.db.seed.conversion_seed import seed_conversions


def seed_all(db: Session, created_by: str = "system") -> None:
    seed_uoms(db, created_by=created_by)
    seed_items(db, created_by=created_by)
    seed_aliases(db, created_by=created_by)
    seed_conversions(db, created_by=created_by)
