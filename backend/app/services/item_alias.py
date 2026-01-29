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


def get_alias_metrics(db: Session) -> List[dict]:
    """
    Compute read-only alias frequency metrics.

    OBSERVATIONAL ONLY:
    This function provides factual alias metrics for diagnostic purposes.
    It must not be used for automation or decision-making.

    Returns:
        List of dicts with alias_id, alias_name, master_item_id, seen_count.
    """
    from app.db.models.mart_bill_item import MartBillItem
    from sqlalchemy import func

    # Get all aliases
    aliases = db.query(ItemAlias).all()

    # Pre-compute seen counts: count MartBillItem records matching each alias_name
    # Case-insensitive matching
    results = []
    for alias in aliases:
        if not alias.alias_name:
            seen_count = 0
        else:
            # Count how many times this exact alias name appears in bills
            seen_count = (
                db.query(func.count(MartBillItem.id))
                .filter(
                    func.lower(MartBillItem.item_name)
                    == func.lower(alias.alias_name.strip())
                )
                .scalar()
                or 0
            )

        results.append(
            {
                "alias_id": alias.id,
                "alias_name": alias.alias_name,
                "alias_code": alias.alias_code,
                "master_item_id": alias.master_item_id,
                "seen_count": seen_count,
                # mapping_events: null - history not tracked
                "mapping_events": None,
            }
        )

    return results


def get_item_alias_aggregates(db: Session, item_id: int) -> dict:
    """
    Compute read-only item-level alias aggregates.

    OBSERVATIONAL ONLY:
    This function provides factual item-level alias metrics for diagnostic purposes.
    It must not be used for automation or decision-making.

    Returns:
        Dict with alias_count, high_frequency_aliases, alias_noise_flag.
    """
    from app.db.models.mart_bill_item import MartBillItem
    from sqlalchemy import func

    # Get aliases for this item
    aliases = db.query(ItemAlias).filter(ItemAlias.master_item_id == item_id).all()
    alias_count = len(aliases)

    # Compute seen_count for each alias
    HIGH_FREQ_THRESHOLD = 3
    high_freq_count = 0

    for alias in aliases:
        if not alias.alias_name:
            continue
        seen_count = (
            db.query(func.count(MartBillItem.id))
            .filter(
                func.lower(MartBillItem.item_name)
                == func.lower(alias.alias_name.strip())
            )
            .scalar()
            or 0
        )

        if seen_count >= HIGH_FREQ_THRESHOLD:
            high_freq_count += 1

    # alias_noise_flag: TRUE if >=3 aliases AND >=2 high-frequency
    alias_noise_flag = alias_count >= 3 and high_freq_count >= 2

    return {
        "alias_count": alias_count,
        "high_frequency_aliases": high_freq_count,
        "alias_noise_flag": alias_noise_flag,
    }
