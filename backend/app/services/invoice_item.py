from datetime import datetime
import json
from sqlalchemy.orm import Session
from typing import Optional, List
from app.db.models.invoice_item import InvoiceItem
from app.db.schemas.invoice_item import InvoiceItemUpdate
from app.db.models.audit_log import AuditLog
from app.db.models.invoice import Invoice

def recalculate_invoice_total(db: Session, invoice_id: int) -> None:
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if invoice:
        invoice.total_amount = sum(item.total for item in invoice.items)
        invoice.updated_at = datetime.utcnow()
        db.add(invoice)
        db.commit()

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
    
    recalculate_invoice_total(db, item.invoice_id)
    return item


def delete_invoice_item(db: Session, item_id: int) -> bool:
    item = db.query(InvoiceItem).filter(InvoiceItem.id == item_id).first()
    if not item:
        return False
    
    invoice_id = item.invoice_id  # capture before delete
    
    db.delete(item)
    db.commit()
    
    recalculate_invoice_total(db, invoice_id)

    return True
