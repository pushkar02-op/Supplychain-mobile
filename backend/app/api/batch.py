from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.db.schemas.batch import BatchCreate, BatchRead, BatchUpdate
from app.services.batch import create_batch, get_batch, get_all_batches, get_batches_by_item_with_quantity, update_batch, delete_batch
from app.db.session import get_db

router = APIRouter(prefix="/batch", tags=["Batches"])

@router.post("/", response_model=BatchRead, status_code=status.HTTP_201_CREATED)
def create(entry: BatchCreate, db: Session = Depends(get_db)):
    return create_batch(db=db, entry=entry, created_by=1)

@router.get("/", response_model=List[BatchRead])
def read_all(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return get_all_batches(db=db, skip=skip, limit=limit)

@router.get("/by-item/{item_id}", response_model=List[BatchRead])
def get_batches_by_item(item_id: int, db: Session = Depends(get_db)):
    return get_batches_by_item_with_quantity(db, item_id)

@router.get("/{batch_id}", response_model=BatchRead)
def read_one(batch_id: int, db: Session = Depends(get_db)):
    batch = get_batch(db=db, batch_id=batch_id)
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    return batch

@router.put("/{batch_id}", response_model=BatchRead)
def update(batch_id: int, entry_update: BatchUpdate, db: Session = Depends(get_db)):
    updated = update_batch(db=db, batch_id=batch_id, entry_update=entry_update, updated_by=1)
    if not updated:
        raise HTTPException(status_code=404, detail="Batch not found")
    return updated

@router.delete("/{batch_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(batch_id: int, db: Session = Depends(get_db)):
    success = delete_batch(db=db, batch_id=batch_id)
    if not success:
        raise HTTPException(status_code=404, detail="Batch not found")
    return None
