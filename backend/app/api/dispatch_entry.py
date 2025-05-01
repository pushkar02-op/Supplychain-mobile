from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryRead,
    DispatchEntryUpdate,
)
from app.services.dispatch_entry import (
    create_dispatch_entry,
    get_dispatch_entry,
    get_all_dispatch_entries,
    update_dispatch_entry,
    delete_dispatch_entry,
)
from app.db.session import get_db

router = APIRouter(prefix="/dispatch-entries", tags=["Dispatch Entries"])

@router.post("/", response_model=DispatchEntryRead, status_code=status.HTTP_201_CREATED)
def create_route(entry: DispatchEntryCreate, db: Session = Depends(get_db)):
    return create_dispatch_entry(db, entry, created_by="system")  # TODO: current user

@router.get("/", response_model=List[DispatchEntryRead])
def read_all(
    skip: int = 0,
    limit: int = 100,
    dispatch_date: Optional[date] = Query(None),
    mart_name: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    return get_all_dispatch_entries(
        db=db,
        skip=skip,
        limit=limit,
        dispatch_date=dispatch_date,
        mart_name=mart_name
    )


@router.get("/{id}", response_model=DispatchEntryRead)
def read_one(id: int, db: Session = Depends(get_db)):
    entry = get_dispatch_entry(db, id)
    if not entry:
        raise HTTPException(status_code=404, detail="Dispatch entry not found")
    return entry

@router.put("/{id}", response_model=DispatchEntryRead)
def update_route(id: int, entry: DispatchEntryUpdate, db: Session = Depends(get_db)):
    updated = update_dispatch_entry(db, id, entry, updated_by="system")
    if not updated:
        raise HTTPException(status_code=404, detail="Dispatch entry not found")
    return updated

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_route(id: int, db: Session = Depends(get_db)):
    success = delete_dispatch_entry(db, id)
    if not success:
        raise HTTPException(status_code=404, detail="Dispatch entry not found")
    return None
