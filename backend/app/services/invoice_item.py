from sqlalchemy.orm import Session
from typing import Optional, List
from app.db.models.invoice_item import InvoiceItem
from app.db.schemas.invoice_item import InvoiceItemUpdate


def get_items_by_invoice(db: Session, invoice_id: int) -> List[InvoiceItem]:
    return db.query(InvoiceItem).filter(InvoiceItem.invoice_id == invoice_id).all()


def update_invoice_item(db: Session, item_id: int, update_data: InvoiceItemUpdate) -> Optional[InvoiceItem]:
    item = db.query(InvoiceItem).filter(InvoiceItem.id == item_id).first()
    if not item:
        return None
    for field, value in update_data.dict(exclude_unset=True).items():
        setattr(item, field, value)
    db.commit()
    db.refresh(item)
    return item


def delete_invoice_item(db: Session, item_id: int) -> bool:
    item = db.query(InvoiceItem).filter(InvoiceItem.id == item_id).first()
    if not item:
        return False
    db.delete(item)
    db.commit()
    return True
