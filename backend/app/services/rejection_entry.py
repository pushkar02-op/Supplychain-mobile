"""
Service functions for rejection entry management.
Handles creation and queries of rejection logs.
"""

import logging
from datetime import date
from decimal import Decimal
from typing import List, Optional

from app.core.exceptions import AppException, UOMConfigurationError
from app.db.models.batch import Batch
from app.db.models.rejection_entry import RejectionEntry
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.db.schemas.rejection_entry import RejectionEntryCreate
from app.services.audit import log_action
from app.services.financial_lock import enforce_financial_lock, enforce_lock_for_entity
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_rejection_entry(
    db: Session,
    entry: RejectionEntryCreate,
    created_by: Optional[str] = None,
    idempotency_key: Optional[str] = None,
    warehouse_id: Optional[int] = None,
) -> RejectionEntry:
    """
    Create a rejection entry and decrement batch quantity.

    Args:
        db (Session): Database session.
        entry (RejectionEntryCreate): Rejection data.
        created_by (Optional[str]): Creator ID.

    Returns:
        RejectionEntry: Created rejection record.

    Raises:
        AppException: If batch invalid or insufficient quantity.
    """
    logger.info(
        f"Creating rejection entry for batch_id={entry.batch_id}, qty={entry.quantity}, idempotency_key={idempotency_key}"
    )

    if idempotency_key:
        from app.utils.idempotency import check_idempotency, save_idempotency_record

        existing_record = check_idempotency(
            db, idempotency_key, "create_rejection_entry", entry.dict()
        )
        if existing_record:
            return db.get(RejectionEntry, existing_record.result_entity_id)

    # Lock batch to prevent overselling during rejection
    # Lock batch to prevent overselling during rejection
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).with_for_update().first()
    if not batch:
        logger.error(f"Batch not found id={entry.batch_id}")
        raise AppException("Batch not found", status_code=404)
    if warehouse_id is not None and batch.warehouse_id != warehouse_id:
        raise AppException(
            "Unauthorized warehouse access",
            status_code=403,
            rule_id="AUT-004",
            metadata={"warehouse_id": warehouse_id},
        )
    enforce_financial_lock(db, batch.warehouse_id, entry.rejection_date)

    # Validation Check (convert if units differ)
    deduct_qty = Decimal(str(entry.quantity))
    if entry.unit != batch.unit:
        try:
            factor_to_batch = get_conversion_factor(
                db, batch.item_id, entry.unit, batch.unit
            )
            deduct_qty = deduct_qty * factor_to_batch
        except Exception:
            # If conversion fails, we can't reliably validate or deduct.
            # Assuming same unit is safer OR fail?
            # Fail is better for data integrity.
            raise AppException(
                f"Cannot convert rejection unit {entry.unit} to batch unit {batch.unit}",
                status_code=400,
            )

    if batch.quantity < deduct_qty:
        msg = f"Cannot reject {entry.quantity} {entry.unit}. Only {batch.quantity} {batch.unit} available"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    rejection_data = entry.dict(exclude={"warehouse_id"})
    rej = RejectionEntry(
        **rejection_data,
        # unit=entry.unit, # entry.dict() includes unit
        item_id=batch.item_id,
        warehouse_id=batch.warehouse_id,
        created_by=user_name,
        created_by_id=user_id,
        updated_by=user_name,
    )
    try:
        db.add(rej)
        # Direct NUMERIC update (Stage 3: Cleanup)
        batch.quantity -= deduct_qty
        db.flush()
        db.refresh(rej)
        logger.debug(f"Created rejection id={rej.id}")

        try:
            from app.db.models.item import Item

            item = db.get(Item, batch.item_id)
            if not item or not item.default_uom_code:
                raise UOMConfigurationError(
                    f"Item id={batch.item_id} has no default UOM configured. Cannot record rejection ledger."
                )
            target_unit = item.default_uom_code

            factor = get_conversion_factor(db, batch.item_id, entry.unit, target_unit)
        except AppException as e:
            logger.error(f"Conversion lookup failed: {e}")
            raise

        base_qty = Decimal(str(entry.quantity)) * factor

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=batch.item_id,
                batch_id=entry.batch_id,
                txn_type="OUT",
                raw_qty=entry.quantity,
                raw_unit=entry.unit,
                base_qty=base_qty,
                base_unit=target_unit,
                ref_type="rejection_entry",
                ref_id=rej.id,
                remarks=f"Rejection: {entry.reason or 'No reason provided'}",
            ),
            actor_user_id=user_id,
        )
        db.flush()  # Ensure ID is generated before commit

        if idempotency_key:
            save_idempotency_record(
                db,
                idempotency_key,
                "create_rejection_entry",
                entry.dict(),
                "rejection_entry",
                rej.id,
            )

        try:
            log_action(
                db=db,
                actor_user_id=user_id,
                action_type="rejection_created",
                entity_type="rejection_entry",
                entity_id=rej.id,
                metadata={
                    "warehouse_id": batch.warehouse_id,
                    "batch_id": entry.batch_id,
                    "rejection_date": str(entry.rejection_date),
                    "quantity": str(entry.quantity),
                },
            )
        except Exception:
            logger.warning("Audit log failed for rejection_created", exc_info=True)

        db.commit()
        return rej
    except Exception:
        db.rollback()
        logger.exception("Failed to create rejection entry")
        raise AppException("Rejection entry creation failed", status_code=500)


def reverse_rejection_entry(
    db: Session, rejection_id: int, user_id: int, warehouse_id: Optional[int] = None
) -> bool:
    """
    Reverse a rejection entry by soft-deleting it and creating a compensating adjustment.

    Args:
        db (Session): Database session.
        rejection_id (int): ID of the rejection to reverse.
        user_id (int): User performing the reversal.

    Returns:
        bool: True if successful.

    Raises:
        AppException: If rejection not found or already reversed.
    """
    logger.info(f"Reversing rejection entry id={rejection_id} by user_id={user_id}")

    rej = (
        db.query(RejectionEntry)
        .filter(RejectionEntry.id == rejection_id)
        .with_for_update()
        .first()
    )
    if not rej:
        raise AppException("Rejection entry not found", status_code=404)
    if warehouse_id is not None and rej.warehouse_id != warehouse_id:
        raise AppException(
            "Unauthorized warehouse access",
            status_code=403,
            rule_id="AUT-004",
            metadata={"warehouse_id": warehouse_id},
        )
    enforce_lock_for_entity(db, rej, rej.rejection_date)

    if not rej.is_active:
        raise AppException("Rejection entry is already voided", status_code=400)

    # 1. Soft Delete
    rej.is_active = False

    # 2. Compensating Adjustment (Add back quantity)
    batch = db.query(Batch).filter(Batch.id == rej.batch_id).with_for_update().first()
    if not batch:
        # Should not happen as Batch is FK, but defensiveness
        raise AppException("Batch associated with rejection not found", status_code=404)

    # We need to add back the converted quantity if unit differs
    # But batch.quantity is in batch.unit.
    # Rejection qty is in rej.unit.
    # Logic repeats from create.

    add_back_qty = Decimal(str(rej.quantity))
    if rej.unit != batch.unit:
        try:
            factor_to_batch = get_conversion_factor(
                db, rej.item_id, rej.unit, batch.unit
            )
            add_back_qty = add_back_qty * factor_to_batch
        except Exception:
            # Critical failure if we can't convert back
            raise AppException(
                "Cannot convert rejection unit back to batch unit", status_code=500
            )

    batch.quantity += add_back_qty

    # 3. Ledger Entry (Compensating)
    try:
        from app.db.models.item import Item

        item = db.get(Item, rej.item_id)
        if not item or not item.default_uom_code:
            raise UOMConfigurationError(f"Item {rej.item_id} default UOM missing")

        target_unit = item.default_uom_code
        factor = get_conversion_factor(db, rej.item_id, rej.unit, target_unit)
        base_qty = Decimal(str(rej.quantity)) * factor

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=rej.item_id,
                batch_id=rej.batch_id,
                txn_type="ADJUST",  # Compensating Adjustment
                raw_qty=rej.quantity,  # Positive logic handles "ADJUST" type?
                # Wait, ADJUST type in create_inventory_txn usually expects signed?
                # Actually, standard ADJUST logic depends on how it's treated.
                # Let's check inventory_txn logic quickly?
                # Assuming ADJUST: if raw_qty is positive, it adds?
                # Rejections were OUT. So we create ADJUST with POSITIVE quantity to reverse.
                raw_unit=rej.unit,
                base_qty=base_qty,
                base_unit=target_unit,
                ref_type="rejection_reversal",  # Explicit ref type
                ref_id=rej.id,
                remarks=f"Reversal of Rejection #{rej.id}",
            ),
            actor_user_id=user_id,
        )

        try:
            log_action(
                db=db,
                actor_user_id=user_id,
                action_type="rejection_reversed",
                entity_type="rejection_entry",
                entity_id=rej.id,
                metadata={
                    "warehouse_id": rej.warehouse_id,
                    "batch_id": rej.batch_id,
                    "quantity": str(rej.quantity),
                },
            )
        except Exception:
            logger.warning("Audit log failed for rejection_reversed", exc_info=True)

        db.commit()
        return True

    except Exception as e:
        db.rollback()
        logger.exception(f"Failed to reverse rejection {rejection_id}: {e}")
        raise AppException("Rejection reversal failed", status_code=500)


def get_all_rejections(
    db: Session, warehouse_id: Optional[int] = None
) -> List[RejectionEntry]:
    """
    Retrieve all rejection entries ordered by date desc.

    Args:
        db (Session): Database session.

    Returns:
        List[RejectionEntry]: List of rejections.
    """
    logger.debug("Fetching all rejection entries")
    q = db.query(RejectionEntry)
    if warehouse_id is not None:
        q = q.filter(RejectionEntry.warehouse_id == warehouse_id)
    return q.order_by(RejectionEntry.rejection_date.desc()).all()


def get_rejections_by_date_and_items(
    db: Session,
    rejection_date: date,
    warehouse_id: Optional[int] = None,
    item_ids: Optional[List[int]] = None,
    skip: int = 0,
    limit: int = 50,
) -> dict:
    """
    Retrieve rejections filtered by date and optional item IDs with pagination.

    Args:
        db (Session): Database session.
        rejection_date (date): Filter date.
        item_ids (Optional[List[int]]): Filter item IDs.
        skip (int): Offset.
        limit (int): Page size.

    Returns:
        dict: Pagination result (items, total, skip, limit, has_more).
    """
    from sqlalchemy.orm import joinedload

    logger.debug(
        f"Fetching rejections for date={rejection_date}, items={item_ids}, skip={skip}, limit={limit}"
    )
    q = db.query(RejectionEntry).filter(RejectionEntry.rejection_date == rejection_date)
    if warehouse_id is not None:
        q = q.filter(RejectionEntry.warehouse_id == warehouse_id)

    if item_ids:
        q = q.filter(RejectionEntry.item_id.in_(item_ids))

    # Calculate total matching records
    total = q.count()

    # Apply pagination and sorting
    # Improve performance by eager loading relations to avoid N+1
    items = (
        q.order_by(RejectionEntry.created_at.desc())
        .options(joinedload(RejectionEntry.batch), joinedload(RejectionEntry.item))
        .offset(skip)
        .limit(limit)
        .all()
    )

    return {
        "items": items,
        "skip": skip,
        "limit": limit,
        "total": total,
        "has_more": (skip + len(items)) < total,
    }
