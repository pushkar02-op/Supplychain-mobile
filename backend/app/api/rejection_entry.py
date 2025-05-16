from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.schemas.rejection_entry import (
    RejectionEntryCreate,
    RejectionEntryRead,
)
from app.services.rejection_entry import create_rejection_entry, get_all_rejections, get_rejections_by_date_and_items
from app.db.session import get_db

router = APIRouter(prefix="/rejection-entries", tags=["Rejection Entries"])

@router.post("/", response_model=RejectionEntryRead, status_code=status.HTTP_201_CREATED)
def create_route(entry: RejectionEntryCreate, db: Session = Depends(get_db)):
    print(entry)
    return create_rejection_entry(db, entry, created_by="system")

@router.get("/", response_model=List[RejectionEntryRead])
def read_all(db: Session = Depends(get_db)):
    return get_all_rejections(db)

@router.get("/list", response_model=List[RejectionEntryRead])
def get_filtered_rejections(
    date: date = Query(..., description="Rejection date"),
    item_ids: Optional[List[int]] = Query(None),
    db: Session = Depends(get_db),
):
    return get_rejections_by_date_and_items(db=db, rejection_date=date, item_ids=item_ids)

