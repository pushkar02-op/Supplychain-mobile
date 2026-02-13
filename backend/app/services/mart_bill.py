"""
Service functions for invoice management.
Handles saving, parsing, and CRUD operations for invoices.
"""

import hashlib
import logging
import os
from datetime import date
from typing import Dict, List, Optional, Union

from app.core.config import settings
from app.core.exceptions import AppException
from app.core.storage.local import LocalDiskStorage
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.uom import UOM
from app.db.schemas.mart_bill import MartBillRead, MartBillUpdate
from app.services.item_alias import get_alias_by_code_or_name
from app.utils.invoice_parser import process_pdf
from fastapi import UploadFile
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

logger = logging.getLogger(__name__)

# Initialize Storage Service
# Using . because existing file_paths are relative to project root/working directory (e.g. 'invoices/foo.pdf')
# If we used STORAGE_ROOT='invoices', then we'd need to strip 'invoices/' from keys or handle migration.
# For minimal disruption, we treat the project root as the storage root, and allow keys to be 'invoices/foo.pdf'
# However, the requirement is "Decouple".
# If we set base_path=settings.STORAGE_ROOT (which defaults to 'invoices'), then:
# New saves: save(bytes, 'foo.pdf') -> writes to 'invoices/foo.pdf'. Key returned: 'foo.pdf'.
# Old data: file_path='invoices/old.pdf'.
# get_path('invoices/old.pdf') -> 'invoices/invoices/old.pdf' (WRONG).
#
# Solution:
# We need logic to handle legacy keys.
# OR we simply continue to use the 'invoices' folder as the root for NEW files, and for OLD files we hope they work?
# No, we must support old files.
#
# Best approach for "Preserve Current Behavior" + "Infrastructure Refactor":
# 1. Initialize storage with base_path = project root (or wherever 'invoices' folder lives relative to CWD).
#    Currently CWD is /app. 'invoices' is /app/invoices.
#    So storage root = /app (or ".").
# 2. When saving, we purposely prepend 'invoices/' to the filename if not present, OR we rely on caller.
#    Actually, the previous code did: `os.path.join(settings.INVOICE_UPLOAD_DIR, filename)`.
#    So the "key" was `invoices/filename`.
#    If we init storage at `.`, then save(data, 'invoices/filename') works perfectly.
#    And exists('invoices/old.pdf') works.
#    This seems the safest path for "Infrastructure Refactor" without data migration.

storage = LocalDiskStorage(base_path=".")


async def save_and_process_mart_bill(
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

    existing = db.query(MartBill).filter_by(file_hash=file_hash).first()
    if existing:
        logger.warning("Duplicate mart bill detected")
        return {
            "filename": filename,
            "success": False,
            "error": "Duplicate mart bill detected",
        }

    # Construct Key (Legacy behavior: keep using 'invoices/' prefix)
    # We use settings.INVOICE_UPLOAD_DIR to maintain directory structure.
    storage_key = os.path.join(settings.INVOICE_UPLOAD_DIR, filename)

    # Save using storage service
    await storage.save(file_bytes, storage_key)

    # Get absolute path for parser (Parser requires path string)
    upload_path = storage.get_path(storage_key)
    logger.debug(f"Saved file to {upload_path}")

    try:
        df, invoice_date, mart_name = process_pdf(upload_path)
        from decimal import Decimal as _D

        total_amount = _D(str(df["Total"].sum()))

        mart = db.query(Mart).filter(Mart.name == mart_name).first()
        if not mart:
            raise AppException("Mart not found", status_code=404)
        from app.utils.audit import resolve_user_audit

        user_name, user_id = resolve_user_audit(db, created_by)

        inv = MartBill(
            invoice_date=invoice_date,
            mart_id=mart.id,
            total_amount=total_amount,
            file_path=storage_key,  # Store key (which happens to be relative path)
            file_hash=file_hash,
            created_by=user_name,
            created_by_id=user_id,
            updated_by=user_name,
            status="NEEDS_REVIEW",
            remarks="Uploaded from mobile",
        )
        db.add(inv)
        db.flush()
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
                MartBillItem(
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
        logger.info(f"Invoice {inv.id} saved. User={created_by}. Items={len(items)}")
        return {
            "filename": filename,
            "success": True,
            "invoice_id": inv.id,
            "unmapped_items": unmapped_items,
        }

    except Exception:
        logger.exception("Failed to process invoice")
        raise AppException("Invoice processing failed", status_code=500)


def get_mart_bill_by_id(db: Session, invoice_id: int) -> Optional[MartBill]:
    """
    Retrieve an invoice by ID.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        Optional[Invoice]: Invoice or None.
    """
    logger.debug(f"Retrieving invoice id={invoice_id}")
    return db.query(MartBill).filter(MartBill.id == invoice_id).first()


def get_all_mart_bills(
    db: Session,
    invoice_date: Optional[str] = None,
    mart_name: Optional[str] = None,
    search: Optional[str] = None,
) -> List[MartBill]:
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
    query = db.query(MartBill)
    if invoice_date:
        query = query.filter(MartBill.invoice_date == invoice_date)
    if mart_name:
        query = query.filter(MartBill.mart_name == mart_name)
    if search:
        term = f"%{search}%"
        query = query.filter(or_(MartBill.mart_name.ilike(term)))
    return query.order_by(MartBill.invoice_date.desc()).all()


def get_mart_bills_paginated(
    db: Session,
    invoice_date: Optional[date] = None,
    mart_id: Optional[int] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 20,
) -> Dict[str, Union[int, List[Dict], bool]]:
    """
    Retrieve invoices with optional filters and pagination.
    Encapsulates logic previously in the API controller.

    Args:
        db (Session): Database session.
        invoice_date (Optional[date]): Filter by invoice date.
        mart_id (Optional[int]): Filter by mart id.
        search (Optional[str]): Search term.
        skip (int): Items to skip.
        limit (int): Items to return.

    Returns:
        Dict: Response containing total, skip, limit, has_more, and list of invoice items.
    """
    logger.debug(
        f"Fetching invoices paginated date={invoice_date}, mart_id={mart_id}, search={search}, skip={skip}, limit={limit}"
    )
    query = db.query(MartBill).options(joinedload(MartBill.mart))

    if invoice_date:
        query = query.filter(MartBill.invoice_date == invoice_date)

    if mart_id:
        query = query.filter(MartBill.mart_id == mart_id)

    if search:
        query = query.join(MartBill.mart).filter(
            or_(
                MartBill.mart.has(name=search),
                MartBill.remarks.ilike(f"%{search}%"),
            )
        )

    # Order by date desc, then ID desc
    query = query.order_by(MartBill.invoice_date.desc(), MartBill.id.desc())

    total = query.count()
    invoices = query.offset(skip).limit(limit).all()

    results = []
    for inv in invoices:
        # Use Pydantic conversion but manually inject mart_name to preserve frontend contract
        inv_dict = MartBillRead.from_orm(inv).dict()
        inv_dict["mart_name"] = inv.mart.name if inv.mart else None
        results.append(inv_dict)

    # Calculate has_more
    has_more = (skip + len(results)) < total

    return {
        "items": results,
        "results": results,  # Backward compatibility
        "total": total,
        "skip": skip,
        "next_skip": skip + limit,
        "limit": limit,
        "has_more": has_more,
    }


def update_mart_bill(
    db: Session, invoice_id: int, data: MartBillUpdate
) -> Optional[MartBill]:
    """
    Update an existing invoice.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.
        data (InvoiceUpdate): Fields to update.

    Returns:
        Optional[Invoice]: Updated invoice or None.
    """
    logger.info(f"Updating mart bill id={invoice_id}")
    inv = get_mart_bill_by_id(db, invoice_id)
    if not inv:
        logger.error(f"Invoice not found id={invoice_id}")
        return None

    if inv.status == "VERIFIED":
        raise AppException(
            "Cannot edit a verified bill. Unverify it first.", status_code=400
        )

    for field, val in data.dict(exclude_unset=True).items():
        setattr(inv, field, val)
    db.commit()
    db.refresh(inv)
    logger.debug(f"Invoice id={invoice_id} updated")
    return inv


def verify_mart_bill(
    db: Session, invoice_id: int, user_name: str
) -> Optional[MartBill]:
    """
    Lock and verify a mart bill.
    """
    inv = get_mart_bill_by_id(db, invoice_id)
    if not inv:
        return None

    if inv.status == "VERIFIED":
        return inv

    from datetime import datetime

    inv.status = "VERIFIED"
    inv.locked_at = datetime.utcnow()
    inv.locked_by = user_name
    db.commit()
    db.refresh(inv)
    logger.info(f"MartBill {invoice_id} verified by {user_name}")
    return inv


def unverify_mart_bill(db: Session, invoice_id: int) -> Optional[MartBill]:
    """
    Unlock a mart bill for editing.
    """
    inv = get_mart_bill_by_id(db, invoice_id)
    if not inv:
        return None

    # Ideally check for admin here or in API
    inv.status = "NEEDS_REVIEW"
    inv.locked_at = None
    inv.locked_by = None
    db.commit()
    db.refresh(inv)
    return inv


def delete_mart_bill(db: Session, invoice_id: int) -> bool:
    """
    Delete an invoice by ID.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting mart bill id={invoice_id}")
    inv = get_mart_bill_by_id(db, invoice_id)
    if not inv:
        logger.error(f"Invoice not found id={invoice_id}")
        return False
    # Optional: Block delete if VERIFIED? Plan said "Delete (Restricted)".
    # "Forbidden Actions" for VERIFIED include Delete (Restricted).
    # I should check status.
    if inv.status == "VERIFIED":
        # Unless admin? For now block.
        logger.warning(f"Attempt to delete verified bill {invoice_id}")
        return False

    # Delete physical file using storage service
    if inv.file_path:
        storage.delete(inv.file_path)

    db.delete(inv)
    db.commit()
    logger.debug(f"Invoice id={invoice_id} deleted")
    return True


async def replace_mart_bill_file(
    db: Session, invoice_id: int, file: UploadFile, user_name: str
) -> Optional[MartBill]:
    """
    Replace the PDF file for an existing mart bill.
    Resets status to NEEDS_REVIEW to ensure re-verification.
    """
    logger.info(f"Replacing file for mart bill id={invoice_id}")
    inv = get_mart_bill_by_id(db, invoice_id)
    if not inv:
        return None

    # Delete old file if it exists
    if inv.file_path and storage.exists(inv.file_path):
        try:
            storage.delete(inv.file_path)
        except Exception:
            logger.warning(
                f"Failed to delete old file {inv.file_path}, proceeding with replacement"
            )

    # Save new file
    filename = file.filename
    file_bytes = await file.read()
    file_hash = hashlib.sha256(file_bytes).hexdigest()

    # Use same logic as save_and_process for key generation
    storage_key = os.path.join(settings.INVOICE_UPLOAD_DIR, filename)
    await storage.save(file_bytes, storage_key)

    # Update metadata
    inv.file_path = storage_key
    inv.file_hash = file_hash
    inv.updated_by = user_name

    # Reset Lifecycle Status
    inv.status = "NEEDS_REVIEW"
    inv.locked_at = None
    inv.locked_by = None

    db.commit()
    db.refresh(inv)
    logger.info(
        f"Replaced file for mart bill {invoice_id}, status reset to NEEDS_REVIEW"
    )
    return inv
