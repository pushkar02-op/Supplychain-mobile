from typing import List, Optional
from sqlalchemy.orm import Session
from app.db.models.views.inventory_summary import InventorySummary
from app.db.models.views.pnl_summary import PnlSummary
from app.db.schemas.inventory_summary import InventorySummaryRead
from app.db.schemas.pnl_summary import PnlSummaryRead

def get_inventory_report(db: Session, item_id: Optional[int]) -> List[InventorySummaryRead]:
    q = db.query(InventorySummary)
    if item_id:
        q = q.filter(InventorySummary.item_id == item_id)
    return q.all()

def get_pnl_report(db: Session, start: Optional[str], end: Optional[str]) -> List[PnlSummaryRead]:
    q = db.query(PnlSummary)
    if start:
        q = q.filter(PnlSummary.date >= start)
    if end:
        q = q.filter(PnlSummary.date <= end)
    return q.all()
