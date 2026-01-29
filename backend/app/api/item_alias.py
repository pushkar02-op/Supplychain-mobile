from typing import List

from app.db.models.item_alias import ItemAlias
from app.db.schemas.item_alias import ItemAliasCreate, ItemAliasRead
from app.db.session import get_db
from app.services.item_alias import create_alias, get_all_aliases
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

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


@router.get("/metrics", summary="Alias Frequency Metrics (Read-Only)")
def get_metrics(db: Session = Depends(get_db)):
    """
    Get alias frequency metrics for observational purposes.

    OBSERVATIONAL ONLY:
    This endpoint provides factual alias metrics for diagnostic purposes.
    It must not be used for automation or decision-making.

    Returns list of aliases with:
    - alias_id, alias_name, alias_code
    - master_item_id (current mapping)
    - seen_count (times this alias appears in bills)
    - mapping_events (null - history not tracked)
    """
    from app.services.item_alias import get_alias_metrics

    return get_alias_metrics(db)


@router.get("/item/{item_id}/aggregates", summary="Item Alias Aggregates (Read-Only)")
def get_item_aggregates(item_id: int, db: Session = Depends(get_db)):
    """
    Get item-level alias aggregates for observational purposes.

    OBSERVATIONAL ONLY:
    This endpoint provides factual item-level alias metrics for diagnostic purposes.
    It must not be used for automation or decision-making.

    Returns:
    - alias_count: total aliases for this item
    - high_frequency_aliases: count of aliases seen >= 3 times
    - alias_noise_flag: true if item has >=3 aliases with >=2 high-frequency
    """
    from app.services.item_alias import get_item_alias_aggregates

    return get_item_alias_aggregates(db, item_id)
