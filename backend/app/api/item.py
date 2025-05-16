from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.db.schemas.item import ItemCreate, ItemRead, ItemUpdate
from app.services.item import create_item, get_item, get_all_items, get_items_with_available_batches, update_item, delete_item
from app.db.session import get_db

router = APIRouter(prefix="/item", tags=["Items"])

@router.post("/", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
def create(entry: ItemCreate, db: Session = Depends(get_db)):
    return create_item(db=db, entry=entry, created_by=1)

@router.get("/", response_model=List[ItemRead])
def read_all(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return get_all_items(db=db, skip=skip, limit=limit)

@router.get("/with-available-batches", response_model=List[ItemRead])
def get_items_with_batches(db: Session = Depends(get_db)):
    return get_items_with_available_batches(db)

@router.get("/{item_id}", response_model=ItemRead)
def read_one(item_id: int, db: Session = Depends(get_db)):
    item = get_item(db=db, item_id=item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@router.put("/{item_id}", response_model=ItemRead)
def update(item_id: int, entry_update: ItemUpdate, db: Session = Depends(get_db)):
    updated = update_item(db=db, item_id=item_id, entry_update=entry_update, updated_by=1)
    if not updated:
        raise HTTPException(status_code=404, detail="Item not found")
    return updated

@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(item_id: int, db: Session = Depends(get_db)):
    success = delete_item(db=db, item_id=item_id)
    if not success:
        raise HTTPException(status_code=404, detail="Item not found")
    return None

