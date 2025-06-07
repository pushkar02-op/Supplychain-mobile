from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.db.schemas.item_conversion_map import (
    ItemConversionCreate,
    ItemConversionRead,
    ItemConversionUpdate,
)
from app.services.item_conversion_map import (
    create_conversion,
    get_all_conversions,
    get_conversion,
    update_conversion,
    delete_conversion
)
from app.db.session import get_db

router = APIRouter(prefix="/conversions", tags=["Item Conversions"])

@router.post("/", response_model=ItemConversionRead, status_code=status.HTTP_201_CREATED)
def create_conv(entry: ItemConversionCreate, db: Session = Depends(get_db)):
    return create_conversion(db, entry, created_by="system")

@router.get("/", response_model=List[ItemConversionRead])
def list_convs(db: Session = Depends(get_db)):
    return get_all_conversions(db)

@router.get("/{conv_id}", response_model=ItemConversionRead)
def read_conv(conv_id: int, db: Session = Depends(get_db)):
    conv = get_conversion(db, conv_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversion not found")
    return conv

@router.put("/{conv_id}", response_model=ItemConversionRead)
def update_conv(conv_id: int, entry: ItemConversionUpdate, db: Session = Depends(get_db)):
    conv = update_conversion(db, conv_id, entry, updated_by="system")
    if not conv:
        raise HTTPException(status_code=404, detail="Conversion not found")
    return conv

@router.delete("/{conv_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_conv(conv_id: int, db: Session = Depends(get_db)):
    if not delete_conversion(db, conv_id):
        raise HTTPException(status_code=404, detail="Conversion not found")
    return None
