from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.schemas.inventory_summary import InventorySummaryRead
from app.db.schemas.pnl_summary import PnlSummaryRead
from app.services.reports import (
    get_inventory_report,
    get_pnl_report,
)
from app.db.session import get_db

router = APIRouter(prefix="/reports", tags=["Reports"])

@router.get("/inventory", response_model=List[InventorySummaryRead])
def inventory(item_id: Optional[int] = Query(None), db: Session = Depends(get_db)):
    return get_inventory_report(db, item_id)

@router.get("/pnl", response_model=List[PnlSummaryRead])
def pnl(
    start: Optional[str] = Query(None, description="YYYY-MM-DD"),
    end: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    return get_pnl_report(db, start, end)
