"""
Service functions for invoice management.
Handles saving, parsing, and CRUD operations for invoices.
"""

import hashlib
import logging
import os
from datetime import date
from typing import Dict, List, Optional, Union

import aiofiles
from app.core.config import settings
from app.core.exceptions import AppException
from app.db.models.invoice import Invoice
from app.db.models.invoice_item import InvoiceItem
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.uom import UOM
from app.db.schemas.invoice import InvoiceRead, InvoiceUpdate
from app.services.item_alias import get_alias_by_code_or_name
from app.utils.invoice_parser import process_pdf
from fastapi import UploadFile
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

logger = logging.getLogger(__name__)


async def save_and_process_invoice(
    file: UploadFile, db: Session, created_by: str = "system"
) -> Dict[str, Optional[Union[int, str, bool]]]:
    """
    Save uploaded PDF, parse it, insert invoice and items.

    Args:
        file (UploadFile): Uploaded PDF.
        db (Session): Database session.
        created_by (str): Creator identifier.

    Returns:
        dict: Result {filename, success, invoice_id/error}.
    """
    filename = file.filename
    logger.info(f"Processing invoice file '{filename}'")
    file_bytes = await file.read()
    file_hash = hashlib.sha256(file_bytes).hexdigest()

    existing = db.query(Invoice).filter_by(file_hash=file_hash).first()
    if existing:
        logger.warning("Duplicate invoice detected")
        return {
            "filename": filename,
            "success": False,
            "error": "Duplicate invoice detected",
        }

    upload_path = os.path.join(settings.INVOICE_UPLOAD_DIR, filename)
    os.makedirs(settings.INVOICE_UPLOAD_DIR, exist_ok=True)
    async with aiofiles.open(upload_path, "wb") as f:
        await f.write(file_bytes)
    logger.debug(f"Saved file to {upload_path}")
    try:
        df, invoice_date, mart_name = process_pdf(upload_path)
        total_amount = float(df["Total"].sum())

        mart = db.query(Mart).filter(Mart.name == mart_name).first()
        if not mart:
            raise AppException("Mart not found", status_code=404)
        from app.utils.audit import resolve_user_audit

        user_name, user_id = resolve_user_audit(db, created_by)

        inv = Invoice(
            invoice_date=invoice_date,
            mart_id=mart.id,
            total_amount=total_amount,
            file_path=upload_path,
            file_hash=file_hash,
            created_by=user_name,
            created_by_id=user_id,
            updated_by=user_name,
            is_verified=False,
            remarks="Uploaded from mobile",
        )
        db.add(inv)
        db.commit()
        db.refresh(inv)
        logger.debug(f"Created invoice id={inv.id}")

        items = []
        unmapped_items = []
        for _, row in df.iterrows():
            item_code = row["ITEM_CODE"]
            item_name = row["Item"]
            item_uom = row["UOM"]

            alias = get_alias_by_code_or_name(db, code=item_code, name=item_name)

            if alias:
                item_id = alias.master_item_id
            else:
                item_id = None  # Will stay unmapped, flagged later in UI

            if item_id is None:
                # Example: suggest items with similar names or codes
                suggestions = (
                    db.query(Item)
                    .filter(
                        or_(
                            Item.name.ilike(f"%{item_name}%"),
                            Item.item_code.ilike(f"%{item_code}%"),
                        )
                    )
                    .limit(10)
                    .all()
                )
                uoms = {u.id: u.code for u in db.query(UOM).all()}
                suggested_items = [
                    {
                        "id": s.id,
                        "name": s.name,
                        "item_code": s.item_code,
                        "uom": uoms.get(s.default_uom_id),
                    }
                    for s in suggestions
                ]
                unmapped_items.append(
                    {
                        "item_code": item_code,
                        "item_name": item_name,
                        "uom": item_uom,
                        "suggested_items": suggested_items,
                    }
                )

            items.append(
                InvoiceItem(
                    invoice_id=inv.id,
                    item_id=item_id,
                    hsn_code=row["HSN_CODE"],
                    item_code=row["ITEM_CODE"],
                    item_name=item_name,
                    quantity=row["Quantity"],
                    uom=row["UOM"],
                    price=row["Price"],
                    total=row["Total"],
                    invoice_date=invoice_date,
                    store_name=mart_name,
                    created_by=user_name,
                    created_by_id=user_id,
                    updated_by=user_name,
                )
            )
        db.bulk_save_objects(items)
        db.commit()
        logger.info(f"Invoice {inv.id} and {len(items)} items saved")
        return {
            "filename": filename,
            "success": True,
            "invoice_id": inv.id,
            "unmapped_items": unmapped_items,
        }

    except Exception:
        logger.exception("Failed to process invoice")
        raise AppException("Invoice processing failed", status_code=500)


def get_invoice_by_id(db: Session, invoice_id: int) -> Optional[Invoice]:
    """
    Retrieve an invoice by ID.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        Optional[Invoice]: Invoice or None.
    """
    logger.debug(f"Retrieving invoice id={invoice_id}")
    return db.query(Invoice).filter(Invoice.id == invoice_id).first()


def get_all_invoices(
    db: Session,
    invoice_date: Optional[str] = None,
    mart_name: Optional[str] = None,
    search: Optional[str] = None,
) -> List[Invoice]:
    """
    Retrieve all invoices with optional filters.

    Args:
        db (Session): Database session.
        invoice_date (Optional[str]): Filter by date.
        mart_name (Optional[str]): Filter by mart name.
        search (Optional[str]): Search term.

    Returns:
        List[Invoice]: List of invoices.
    """
    logger.debug("Fetching invoices with filters")
    query = db.query(Invoice)
    if invoice_date:
        query = query.filter(Invoice.invoice_date == invoice_date)
    if mart_name:
        query = query.filter(Invoice.mart_name == mart_name)
    if search:
        term = f"%{search}%"
        query = query.filter(or_(Invoice.mart_name.ilike(term)))
    return query.order_by(Invoice.invoice_date.desc()).all()


def get_invoices_paginated(
    db: Session,
    invoice_date: Optional[date] = None,
    mart_id: Optional[int] = None,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
) -> Dict[str, Union[int, List[Dict]]]:
    """
    Retrieve invoices with optional filters and pagination.
    Encapsulates logic previously in the API controller.

    Args:
        db (Session): Database session.
        invoice_date (Optional[date]): Filter by invoice date.
        mart_id (Optional[int]): Filter by mart id.
        search (Optional[str]): Search term.
        page (int): Page number.
        page_size (int): Page size.

    Returns:
        Dict: Response containing total, page, page_size, and list of invoice results.
    """
    logger.debug(
        f"Fetching invoices paginated date={invoice_date}, mart_id={mart_id}, search={search}"
    )
    query = db.query(Invoice).options(joinedload(Invoice.mart))

    if invoice_date:
        query = query.filter(Invoice.invoice_date == invoice_date)

    if mart_id:
        query = query.filter(Invoice.mart_id == mart_id)

    if search:
        query = query.join(Invoice.mart).filter(
            or_(
                Invoice.mart.has(name=search),
                Invoice.remarks.ilike(f"%{search}%"),
            )
        )

    query = query.order_by(Invoice.invoice_date.desc(), Invoice.id.desc())

    total = query.count()
    from app.utils.pagination import calculate_offset

    offset = calculate_offset(page, page_size)
    invoices = query.offset(offset).limit(page_size).all()

    results = []
    for inv in invoices:
        # Use Pydantic conversion but manually inject mart_name to preserve frontend contract
        inv_dict = InvoiceRead.from_orm(inv).dict()
        inv_dict["mart_name"] = inv.mart.name if inv.mart else None
        results.append(inv_dict)

    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "results": results,
    }


def update_invoice(
    db: Session, invoice_id: int, data: InvoiceUpdate
) -> Optional[Invoice]:
    """
    Update an existing invoice.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.
        data (InvoiceUpdate): Fields to update.

    Returns:
        Optional[Invoice]: Updated invoice or None.
    """
    logger.info(f"Updating invoice id={invoice_id}")
    inv = get_invoice_by_id(db, invoice_id)
    if not inv:
        logger.error(f"Invoice not found id={invoice_id}")
        return None
    for field, val in data.dict(exclude_unset=True).items():
        setattr(inv, field, val)
    db.commit()
    db.refresh(inv)
    logger.debug(f"Invoice id={invoice_id} updated")
    return inv


def delete_invoice(db: Session, invoice_id: int) -> bool:
    """
    Delete an invoice by ID.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting invoice id={invoice_id}")
    inv = get_invoice_by_id(db, invoice_id)
    if not inv:
        logger.error(f"Invoice not found id={invoice_id}")
        return False
    db.delete(inv)
    db.commit()
    logger.debug(f"Invoice id={invoice_id} deleted")
    return True
