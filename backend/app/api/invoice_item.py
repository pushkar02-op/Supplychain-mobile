from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.db.session import get_db
from app.services.invoice_item import (
    get_items_by_invoice,
    update_invoice_item,
    delete_invoice_item,
)
from app.db.schemas.invoice_item import InvoiceItemUpdate, InvoiceItemRead

router = APIRouter(prefix="/invoice-items", tags=["Invoice Items"])


@router.get("/{invoice_id}", response_model=List[InvoiceItemRead])
def read_items(invoice_id: int, db: Session = Depends(get_db)):
    return get_items_by_invoice(db, invoice_id)


@router.put("/{item_id}", response_model=InvoiceItemRead)
def update_item(item_id: int, update_data: InvoiceItemUpdate, db: Session = Depends(get_db)):
    updated = update_invoice_item(db, item_id, update_data)
    if not updated:
        raise HTTPException(status_code=404, detail="Item not found")
    return updated


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    if not delete_invoice_item(db, item_id):
        raise HTTPException(status_code=404, detail="Item not found")
    return None
