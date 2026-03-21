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
from app.db.models.item_alias import ItemAlias
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.mart_item_alias import MartItemAlias
from app.db.models.uom import UOM
from app.db.schemas.mart_bill import MartBillRead, MartBillUpdate
from app.services.audit import log_action
from app.services.financial_lock import enforce_financial_lock, enforce_lock_for_entity
from app.services.warehouse_scope import resolve_system_warehouse_id
from app.utils.invoice_parser import process_pdf
from app.utils.invoice_validator import validate_invoice_structure
from app.utils.similarity import compute_match_score
from fastapi import UploadFile
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
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
    file: UploadFile,
    db: Session,
    created_by: str = "system",
    warehouse_id: Optional[int] = None,
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
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)

    # Construct Key (Legacy behavior: keep using 'invoices/' prefix)
    # We use settings.INVOICE_UPLOAD_DIR to maintain directory structure.
    storage_key = os.path.join(settings.INVOICE_UPLOAD_DIR, filename)

    # Save using storage service
    file_saved = False
    commit_success = False
    await storage.save(file_bytes, storage_key)
    file_saved = True

    # Get absolute path for parser (Parser requires path string)
    upload_path = storage.get_path(storage_key)
    logger.debug(f"Saved file to {upload_path}")

    try:
        # Validate PDF structure before parsing
        validation = validate_invoice_structure(upload_path)
        if not validation["is_valid"]:
            raise AppException(
                detail=f"Invalid invoice structure: {', '.join(validation['errors'])}",
                status_code=400,
            )

        df, invoice_date, mart_name = process_pdf(upload_path)

        if not validation["format"]:
            raise AppException(
                detail="Invoice format not supported after parsing",
                status_code=400,
            )
        detected_format = validation["format"]
        from decimal import Decimal as _D

        total_amount = _D(str(df["Total"].sum()))
        enforce_financial_lock(db, resolved_warehouse_id, invoice_date)

        mart = db.query(Mart).filter(Mart.name == mart_name).first()
        if not mart:
            raise AppException("Mart not found", status_code=404)
        from app.utils.audit import resolve_user_audit

        user_name, user_id = resolve_user_audit(db, created_by)

        inv = MartBill(
            invoice_date=invoice_date,
            mart_id=mart.id,
            warehouse_id=resolved_warehouse_id,
            total_amount=total_amount,
            file_path=storage_key,  # Store key (which happens to be relative path)
            file_hash=file_hash,
            created_by=user_name,
            created_by_id=user_id,
            updated_by=user_name,
            status="NEEDS_REVIEW",
            remarks="Uploaded from mobile",
            format_type=detected_format,
        )
        db.add(inv)
        db.flush()
        db.refresh(inv)
        logger.debug(f"Created invoice id={inv.id}")

        # --- Preload alias data for in-memory resolution ---
        mart_aliases = (
            db.query(MartItemAlias).filter(MartItemAlias.mart_id == mart.id).all()
        )
        mart_alias_code_map = {}
        mart_alias_name_map = {}
        for a in mart_aliases:
            if a.alias_code:
                mart_alias_code_map.setdefault(a.alias_code.strip(), a.item_id)
            if a.alias_name:
                mart_alias_name_map.setdefault(a.alias_name.strip().lower(), a.item_id)

        global_aliases = db.query(ItemAlias).all()
        global_code_map = {}
        global_name_map = {}
        for a in global_aliases:
            if a.alias_code:
                global_code_map.setdefault(a.alias_code.strip(), a.master_item_id)
            if a.alias_name:
                global_name_map.setdefault(
                    a.alias_name.strip().lower(), a.master_item_id
                )

        # Preload UOM once (was queried per unmapped item)
        uom_map = {u.id: u.code for u in db.query(UOM).all()}

        # Preload items for suggestion matching (capped to prevent table scan explosion)
        all_items = db.query(Item).limit(5000).all()

        items = []
        unmapped_items = []
        for _, row in df.iterrows():
            item_code = row["ITEM_CODE"]
            item_name = row["Item"]
            item_uom = row["UOM"]

            # In-memory alias resolution (same priority as resolve_alias)
            item_id = None
            code_key = (item_code or "").strip()
            name_key = (item_name or "").strip().lower()

            # Priority 1: Mart alias by code (exact match)
            if code_key and code_key in mart_alias_code_map:
                item_id = mart_alias_code_map[code_key]
            # Priority 2: Mart alias by name (case-insensitive)
            elif name_key and name_key in mart_alias_name_map:
                item_id = mart_alias_name_map[name_key]
            # Priority 3: Global alias by code (exact match)
            elif code_key and code_key in global_code_map:
                item_id = global_code_map[code_key]
            # Priority 4: Global alias by name (case-insensitive)
            elif name_key and name_key in global_name_map:
                item_id = global_name_map[name_key]

            if item_id is None:
                # Fuzzy suggestion matching with confidence scoring
                scored = []
                for s in all_items:
                    name_score = compute_match_score(item_name or "", s.name or "")
                    code_score = compute_match_score(item_code or "", s.item_code or "")
                    score = max(name_score, code_score)
                    if score >= 40:
                        scored.append((score, s))
                scored.sort(key=lambda x: x[0], reverse=True)
                suggested_items = [
                    {
                        "id": s.id,
                        "name": s.name,
                        "item_code": s.item_code,
                        "uom": uom_map.get(s.default_uom_id),
                        "confidence": score,
                    }
                    for score, s in scored[:5]
                ]
                unmapped_items.append(
                    {
                        "item_code": item_code,
                        "item_name": item_name,
                        "uom": item_uom,
                        "suggested_items": suggested_items,
                    }
                )

            resolution_status = "MAPPED" if item_id else "UNRESOLVED"

            items.append(
                MartBillItem(
                    invoice_id=inv.id,
                    item_id=item_id,
                    resolution_status=resolution_status,
                    warehouse_id=resolved_warehouse_id,
                    hsn_code=row.get("HSN_CODE"),
                    item_code=row.get("ITEM_CODE"),
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

        try:
            log_action(
                db=db,
                actor_user_id=user_id,
                action_type="mart_bill_created",
                entity_type="mart_bill",
                entity_id=inv.id,
                metadata={
                    "warehouse_id": resolved_warehouse_id,
                    "invoice_date": str(invoice_date),
                    "total_amount": str(total_amount),
                },
            )
        except Exception:
            logger.warning("Audit log failed for mart_bill_created", exc_info=True)

        try:
            db.commit()
            commit_success = True
        except IntegrityError:
            db.rollback()
            raise AppException(
                "Duplicate invoice upload detected.",
                status_code=409,
            )
        logger.info(f"Invoice {inv.id} saved. User={created_by}. Items={len(items)}")
        return {
            "filename": filename,
            "success": True,
            "invoice_id": inv.id,
            "unmapped_items": unmapped_items,
        }

    except AppException:
        db.rollback()
        if file_saved and not commit_success:
            try:
                storage.delete(storage_key)
            except Exception:
                logger.warning(f"Failed to cleanup orphan file: {storage_key}")
        raise

    except Exception as e:
        db.rollback()
        if file_saved and not commit_success:
            try:
                storage.delete(storage_key)
            except Exception:
                logger.warning(f"Failed to cleanup orphan file: {storage_key}")
        logger.exception(f"Unexpected error processing invoice: {e}")
        raise AppException(
            "Invoice format not supported or structure has changed",
            status_code=400,
        )


def get_mart_bill_by_id(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> Optional[MartBill]:
    """
    Retrieve an invoice by ID.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        Optional[Invoice]: Invoice or None.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Retrieving invoice id={invoice_id}")
    q = db.query(MartBill).filter(
        MartBill.id == invoice_id, MartBill.warehouse_id == resolved_warehouse_id
    )
    return q.first()


def get_all_mart_bills(
    db: Session,
    warehouse_id: int,
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
    query = db.query(MartBill).filter(MartBill.warehouse_id == warehouse_id)
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
    warehouse_id: int,
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
    query = (
        db.query(MartBill)
        .options(joinedload(MartBill.mart))
        .filter(MartBill.warehouse_id == warehouse_id)
    )

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

    # Batch-fetch unresolved counts for all invoices in one query
    invoice_ids = [inv.id for inv in invoices]
    unresolved_counts = {}
    if invoice_ids:
        count_rows = (
            db.query(
                MartBillItem.invoice_id,
                func.count(MartBillItem.id),
            )
            .filter(
                MartBillItem.invoice_id.in_(invoice_ids),
                MartBillItem.resolution_status == "UNRESOLVED",
            )
            .group_by(MartBillItem.invoice_id)
            .all()
        )
        unresolved_counts = {row[0]: row[1] for row in count_rows}

    results = []
    for inv in invoices:
        # Use Pydantic conversion but manually inject mart_name to preserve frontend contract
        inv_dict = MartBillRead.from_orm(inv).dict()
        inv_dict["mart_name"] = inv.mart.name if inv.mart else None
        inv_dict["unresolved_count"] = unresolved_counts.get(inv.id, 0)
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
    db: Session,
    invoice_id: int,
    data: MartBillUpdate,
    warehouse_id: Optional[int] = None,
) -> Optional[MartBill]:
    try:
        return _update_mart_bill_impl(db, invoice_id, data, warehouse_id)
    except Exception:
        db.rollback()
        raise


def _update_mart_bill_impl(
    db: Session,
    invoice_id: int,
    data: MartBillUpdate,
    warehouse_id: Optional[int] = None,
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
    inv = get_mart_bill_by_id(db, invoice_id, warehouse_id=warehouse_id)
    if not inv:
        logger.error(f"Invoice not found id={invoice_id}")
        return None
    enforce_lock_for_entity(db, inv, inv.invoice_date)

    if inv.status == "VERIFIED":
        raise AppException(
            "Cannot edit a verified bill. Unverify it first.", status_code=400
        )

    for field, val in data.dict(exclude_unset=True).items():
        setattr(inv, field, val)

    try:
        log_action(
            db=db,
            actor_user_id=inv.created_by_id,
            action_type="mart_bill_updated",
            entity_type="mart_bill",
            entity_id=inv.id,
            metadata={"warehouse_id": inv.warehouse_id},
        )
    except Exception:
        logger.warning("Audit log failed for mart_bill_updated", exc_info=True)

    db.commit()
    db.refresh(inv)
    logger.debug(f"Invoice id={invoice_id} updated")
    return inv


def verify_mart_bill(
    db: Session, invoice_id: int, user_name: str, warehouse_id: Optional[int] = None
) -> Optional[MartBill]:
    try:
        return _verify_mart_bill_impl(db, invoice_id, user_name, warehouse_id)
    except Exception:
        db.rollback()
        raise


def _verify_mart_bill_impl(
    db: Session,
    invoice_id: int,
    user_name: str,
    warehouse_id: Optional[int] = None,
) -> Optional[MartBill]:
    """
    Lock and verify a mart bill.
    """
    inv = get_mart_bill_by_id(db, invoice_id, warehouse_id=warehouse_id)
    if not inv:
        return None
    enforce_lock_for_entity(db, inv, inv.invoice_date)

    if inv.status == "VERIFIED":
        return inv

    # Block verification if unresolved items exist
    unresolved = (
        db.query(MartBillItem.id)
        .filter(
            MartBillItem.invoice_id == inv.id,
            MartBillItem.resolution_status == "UNRESOLVED",
        )
        .first()
    )
    if unresolved:
        unresolved_count = (
            db.query(MartBillItem)
            .filter(
                MartBillItem.invoice_id == inv.id,
                MartBillItem.resolution_status == "UNRESOLVED",
            )
            .count()
        )
        raise AppException(
            detail=f"{unresolved_count} items are still unresolved. Resolve all items before verification.",
            status_code=400,
        )

    from datetime import datetime

    inv.status = "VERIFIED"
    inv.locked_at = datetime.utcnow()
    inv.locked_by = user_name

    try:
        log_action(
            db=db,
            actor_user_id=inv.created_by_id,
            action_type="mart_bill_verified",
            entity_type="mart_bill",
            entity_id=inv.id,
            metadata={"warehouse_id": inv.warehouse_id, "verified_by": user_name},
        )
    except Exception:
        logger.warning("Audit log failed for mart_bill_verified", exc_info=True)

    db.commit()
    db.refresh(inv)
    logger.info(f"MartBill {invoice_id} verified by {user_name}")
    return inv


def unverify_mart_bill(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> Optional[MartBill]:
    try:
        return _unverify_mart_bill_impl(db, invoice_id, warehouse_id)
    except Exception:
        db.rollback()
        raise


def _unverify_mart_bill_impl(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> Optional[MartBill]:
    """
    Unlock a mart bill for editing.
    """
    inv = get_mart_bill_by_id(db, invoice_id, warehouse_id=warehouse_id)
    if not inv:
        return None

    # Ideally check for admin here or in API
    inv.status = "NEEDS_REVIEW"
    inv.locked_at = None
    inv.locked_by = None

    try:
        log_action(
            db=db,
            actor_user_id=inv.created_by_id,
            action_type="mart_bill_unverified",
            entity_type="mart_bill",
            entity_id=inv.id,
            metadata={"warehouse_id": inv.warehouse_id},
        )
    except Exception:
        logger.warning("Audit log failed for mart_bill_unverified", exc_info=True)

    db.commit()
    db.refresh(inv)
    return inv


def delete_mart_bill(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> bool:
    try:
        return _delete_mart_bill_impl(db, invoice_id, warehouse_id)
    except Exception:
        db.rollback()
        raise


def _delete_mart_bill_impl(
    db: Session, invoice_id: int, warehouse_id: Optional[int] = None
) -> bool:
    """
    Delete an invoice by ID.

    Args:
        db (Session): Database session.
        invoice_id (int): Invoice ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting mart bill id={invoice_id}")
    inv = get_mart_bill_by_id(db, invoice_id, warehouse_id=warehouse_id)
    if not inv:
        logger.error(f"Invoice not found id={invoice_id}")
        return False
    enforce_lock_for_entity(db, inv, inv.invoice_date)
    # Optional: Block delete if VERIFIED? Plan said "Delete (Restricted)".
    # "Forbidden Actions" for VERIFIED include Delete (Restricted).
    # I should check status.
    if inv.status == "VERIFIED":
        # Unless admin? For now block.
        logger.warning(f"Attempt to delete verified bill {invoice_id}")
        return False

    old_file_path = inv.file_path

    inv_wh = inv.warehouse_id
    inv_pk = inv.id
    inv_actor = inv.created_by_id

    try:
        log_action(
            db=db,
            actor_user_id=inv_actor,
            action_type="mart_bill_deleted",
            entity_type="mart_bill",
            entity_id=inv_pk,
            metadata={"warehouse_id": inv_wh},
        )
    except Exception:
        logger.warning("Audit log failed for mart_bill_deleted", exc_info=True)

    db.delete(inv)
    db.commit()

    # Delete physical file AFTER successful commit
    if old_file_path:
        if not storage.delete(old_file_path):
            logger.warning(f"File cleanup failed after delete: {old_file_path}")

    logger.debug(f"Invoice id={invoice_id} deleted")
    return True


async def replace_mart_bill_file(
    db: Session,
    invoice_id: int,
    file: UploadFile,
    user_name: str,
    warehouse_id: Optional[int] = None,
) -> Optional[MartBill]:
    try:
        return await _replace_mart_bill_file_impl(
            db, invoice_id, file, user_name, warehouse_id
        )
    except Exception:
        db.rollback()
        raise


async def _replace_mart_bill_file_impl(
    db: Session,
    invoice_id: int,
    file: UploadFile,
    user_name: str,
    warehouse_id: Optional[int] = None,
) -> Optional[MartBill]:
    """
    Replace the PDF file for an existing mart bill.
    Resets status to NEEDS_REVIEW to ensure re-verification.
    """
    logger.info(f"Replacing file for mart bill id={invoice_id}")
    inv = get_mart_bill_by_id(db, invoice_id, warehouse_id=warehouse_id)
    if not inv:
        return None
    enforce_lock_for_entity(db, inv, inv.invoice_date)

    old_file_path = inv.file_path

    # Save new file FIRST (before any destructive operations)
    filename = file.filename
    file_bytes = await file.read()
    file_hash = hashlib.sha256(file_bytes).hexdigest()
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

    try:
        log_action(
            db=db,
            actor_user_id=inv.created_by_id,
            action_type="mart_bill_file_replaced",
            entity_type="mart_bill",
            entity_id=inv.id,
            metadata={"warehouse_id": inv.warehouse_id, "replaced_by": user_name},
        )
    except Exception:
        logger.warning("Audit log failed for mart_bill_file_replaced", exc_info=True)

    try:
        db.commit()
        db.refresh(inv)
    except Exception:
        db.rollback()
        try:
            storage.delete(storage_key)
        except Exception:
            logger.warning(
                f"Failed to cleanup new file after commit failure: {storage_key}"
            )
        raise

    # Delete old file AFTER successful commit
    if old_file_path and old_file_path != storage_key:
        if not storage.delete(old_file_path):
            logger.warning(f"Failed to delete old file after replace: {old_file_path}")

    logger.info(
        f"Replaced file for mart bill {invoice_id}, status reset to NEEDS_REVIEW"
    )
    return inv
