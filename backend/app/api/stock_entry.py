from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.schemas.stock_entry import (
    StockEntryCreate,
    StockEntryRead,
    StockEntryUpdate,
)
from app.services.stock_entry import (
    create_stock_entry,
    get_stock_entry,
    get_all_stock_entries,
    update_stock_entry,
    delete_stock_entry,
)
from app.db.session import get_db

router = APIRouter(prefix="/stock-entry", tags=["Stock Entry"])


@router.post("/", response_model=StockEntryRead, status_code=status.HTTP_201_CREATED)
def create(entry: StockEntryCreate, db: Session = Depends(get_db)):
    return create_stock_entry(db=db, entry=entry, created_by=1)  # TODO: Use current user ID


@router.get("/", response_model=List[StockEntryRead])
def read_all(date: Optional[date] = None, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return get_all_stock_entries(date=date, db=db, skip=skip, limit=limit)


@router.get("/{stock_entry_id}", response_model=StockEntryRead)
def read_one(stock_entry_id: int, db: Session = Depends(get_db)):
    entry = get_stock_entry(db=db, stock_entry_id=stock_entry_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Stock entry not found")
    return entry


@router.put("/{stock_entry_id}", response_model=StockEntryRead)
def update(stock_entry_id: int, entry_update: StockEntryUpdate, db: Session = Depends(get_db)):
    print(entry_update)
    updated = update_stock_entry(db=db, stock_entry_id=stock_entry_id, entry_update=entry_update, updated_by=1)  
    if not updated:
        raise HTTPException(status_code=404, detail="Stock entry not found")
    return updated


@router.delete("/{stock_entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(stock_entry_id: int, db: Session = Depends(get_db)):
    success = delete_stock_entry(db=db, stock_entry_id=stock_entry_id)
    if not success:
        raise HTTPException(status_code=404, detail="Stock entry not found")
    return None
