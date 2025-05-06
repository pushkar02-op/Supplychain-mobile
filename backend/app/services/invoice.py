import os
from typing import List, Optional
from fastapi import UploadFile
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from app.utils.invoice_parser import process_pdf
from app.core.config import settings
from app.db.models.invoice import Invoice
from app.db.models.invoice_item import InvoiceItem
from app.db.models.item import Item
import aiofiles 
import hashlib
from app.db.schemas.invoice import InvoiceUpdate


async def save_and_process_invoice(file: UploadFile, db: Session, created_by: str = "system") -> dict:
    filename = file.filename
    file_bytes = await file.read()

    # ➕ Generate file hash
    file_hash = hashlib.sha256(file_bytes).hexdigest()

    # ✅ Check for duplicate
    existing = db.query(Invoice).filter_by(file_hash=file_hash).first()
    if existing:
        return {"filename": filename, "success": False, "error": "Duplicate invoice detected"}

    upload_path = os.path.join(settings.INVOICE_UPLOAD_DIR, filename)

    os.makedirs(settings.INVOICE_UPLOAD_DIR, exist_ok=True)
        
    async with aiofiles.open(upload_path, "wb") as f:
        await f.write(file_bytes)

    try:
        df, extracted_date, mart_name = process_pdf(upload_path)

        total_amount = float(df["Total"].sum())

        new_invoice = Invoice(
            invoice_date=extracted_date,
            mart_name=mart_name,
            total_amount=total_amount,
            file_path=upload_path,
            file_hash=file_hash,
            created_by=created_by,
            updated_by=created_by,
            is_verified=False,
            remarks="Uploaded from mobile"
        )

        db.add(new_invoice)
        db.commit()
        db.refresh(new_invoice)

        invoice_items = []

        for _, row in df.iterrows():
            item_name = row['Item']
            existing_item = db.query(Item).filter(func.lower(Item.name) == item_name.lower()).first()

            if not existing_item:
                new_item = Item(
                    name=item_name,
                    default_unit=row['UOM'],
                    created_by=created_by,
                    updated_by=created_by
                )
                db.add(new_item)
                db.flush()
                item_id = new_item.id
            else:
                item_id = existing_item.id

            invoice_items.append(InvoiceItem(
                invoice_id=new_invoice.id,
                item_id=item_id,
                hsn_code=row["HSN_CODE"],
                item_code=row["ITEM_CODE"],
                item_name=item_name,
                quantity=row["Quantity"],
                uom=row["UOM"],
                price=row["Price"],
                total=row["Total"],
                invoice_date=extracted_date,
                store_name=mart_name,
                created_by=created_by,
                updated_by=created_by
            ))

        db.bulk_save_objects(invoice_items)
        db.commit()

        return {"filename": filename, "success": True, "invoice_id": new_invoice.id}
    except Exception as e:
        return {"filename": filename, "success": False, "error": str(e)}
    
def get_invoice_by_id(db: Session, invoice_id: int) -> Invoice:
    return db.query(Invoice).filter(Invoice.id == invoice_id).first()


def get_all_invoices(
    db: Session,
    invoice_date: Optional[str] = None,
    mart_name: Optional[str] = None,
    search: Optional[str] = None,
) -> List[Invoice]:
    query = db.query(Invoice)

    if invoice_date:
        query = query.filter(Invoice.invoice_date == invoice_date)

    if mart_name:
        query = query.filter(Invoice.mart_name == mart_name)

    if search:
        search = f"%{search}%"
        query = query.filter(
            or_(
                Invoice.mart_name.ilike(search),
            )
        )

    return query.order_by(Invoice.invoice_date.desc()).all()


def update_invoice(db: Session, invoice_id: int, data: InvoiceUpdate) -> Optional[Invoice]:
    invoice = get_invoice_by_id(db, invoice_id)
    if not invoice:
        return None

    for field, value in data.dict(exclude_unset=True).items():
        setattr(invoice, field, value)

    db.commit()
    db.refresh(invoice)
    return invoice


def delete_invoice(db: Session, invoice_id: int) -> bool:
    invoice = get_invoice_by_id(db, invoice_id)
    if not invoice:
        return False
    db.delete(invoice)
    db.commit()
    return True