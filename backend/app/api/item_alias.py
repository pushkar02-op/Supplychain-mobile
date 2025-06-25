from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.db.session import get_db
from app.db.models.item_alias import ItemAlias
from app.db.schemas.item_alias import ItemAliasCreate, ItemAliasRead
from app.services.item_alias import create_alias, get_all_aliases

router = APIRouter(prefix="/item-alias", tags=["Item Alias"])


@router.post("/", response_model=ItemAliasRead)
def create(entry: ItemAliasCreate, db: Session = Depends(get_db)):
    return create_alias(db, entry, created_by="system")


@router.get("/", response_model=List[ItemAliasRead])
def read_all(db: Session = Depends(get_db)):
    return get_all_aliases(db)


@router.get("/distinct", response_model=List[ItemAliasRead])
def get_distinct_aliases(db: Session = Depends(get_db)):
    # You can add more filtering if needed
    aliases = db.query(ItemAlias).distinct(ItemAlias.alias_name).all()
    return aliases
