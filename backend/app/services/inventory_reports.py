import logging
from datetime import date
from decimal import Decimal
from typing import List

from app.db.models.inventory_txn import InventoryTxn
from app.db.models.item import Item
from app.db.schemas.inventory_reports import TopMovingItem
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def get_top_moving_items(
    db: Session, warehouse_id: int, limit: int = 5
) -> List[TopMovingItem]:
    """
    Return top moving items (outflow) for today.
    """
    today = date.today()
    rows = (
        db.query(
            Item.id.label("item_id"),
            Item.name.label("item_name"),
            func.sum(InventoryTxn.base_qty).label("total_out"),
        )
        .join(Item, Item.id == InventoryTxn.item_id)
        .filter(InventoryTxn.warehouse_id == warehouse_id)
        .filter(func.date(InventoryTxn.created_at) >= today)
        .filter(InventoryTxn.txn_type.in_(("OUT", "DISPATCH")))
        .group_by(Item.id, Item.name)
        .order_by(func.sum(InventoryTxn.base_qty).desc())
        .limit(limit)
        .all()
    )

    results: List[TopMovingItem] = []
    for row in rows:
        total = row.total_out
        if isinstance(total, Decimal):
            total = float(total)
        results.append(
            TopMovingItem(
                item_id=row.item_id,
                item_name=row.item_name,
                total_out=total or 0.0,
            )
        )
    logger.info("Top moving items fetched count=%s", len(results))
    return results
