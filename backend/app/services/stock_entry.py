"""
Service functions for stock entry management.
Handles receiving and adjustment of stock entries and underlying batches.
"""

import logging
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

from app.core.exceptions import AppException, UOMConfigurationError
from app.db.models.batch import Batch
from app.db.models.stock_entry import StockEntry
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.db.schemas.stock_entry import StockEntryCreate, StockEntryUpdate
from app.services.audit import log_action
from app.services.financial_lock import enforce_financial_lock, enforce_lock_for_entity
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from app.services.warehouse_scope import resolve_system_warehouse_id
from sqlalchemy import and_
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_stock_entry(
    db: Session,
    entry: StockEntryCreate,
    created_by: Optional[int] = None,
    idempotency_key: Optional[str] = None,
    warehouse_id: Optional[int] = None,
) -> StockEntry:
    try:
        return _create_stock_entry_impl(
            db, entry, created_by, idempotency_key, warehouse_id
        )
    except Exception:
        db.rollback()
        raise


def _create_stock_entry_impl(
    db: Session,
    entry: StockEntryCreate,
    created_by: Optional[int] = None,
    idempotency_key: Optional[str] = None,
    warehouse_id: Optional[int] = None,
) -> StockEntry:
    """
    Create a stock entry, grouping into an existing batch or creating a new one.

    Args:
        db (Session): Database session.
        entry (StockEntryCreate): Data for stock entry.
        created_by (Optional[int]): Creator ID.

    Returns:
        StockEntry: Created stock entry.
    """
    logger.info(
        f"Creating stock entry for item_id={entry.item_id}, qty={entry.quantity}, idempotency_key={idempotency_key}"
    )

    resolved_warehouse_id = resolve_system_warehouse_id(
        db, warehouse_id if warehouse_id is not None else entry.warehouse_id
    )
    enforce_financial_lock(db, resolved_warehouse_id, entry.received_date)

    if idempotency_key:
        from app.utils.idempotency import check_idempotency, save_idempotency_record

        existing_record = check_idempotency(
            db, idempotency_key, "create_stock_entry", entry.dict()
        )
        if existing_record:
            return get_stock_entry(db, existing_record.result_entity_id)

    # 1) Find-or-create Batch
    batch_query = db.query(Batch).filter(
        and_(
            Batch.item_id == entry.item_id,
            Batch.received_at == entry.received_date,
        )
    )
    if resolved_warehouse_id is not None:
        batch_query = batch_query.filter(Batch.warehouse_id == resolved_warehouse_id)
    batch = batch_query.with_for_update().first()

    if batch:
        if (
            resolved_warehouse_id is not None
            and batch.warehouse_id != resolved_warehouse_id
        ):
            raise AppException(
                "Unauthorized warehouse access",
                status_code=403,
                rule_id="AUT-004",
                metadata={"warehouse_id": resolved_warehouse_id},
            )
        # Direct NUMERIC update (Stage 3: Cleanup)
        batch.quantity += Decimal(str(entry.quantity))
        batch.updated_by = created_by
        batch.updated_at = datetime.utcnow()
        db.flush()
        logger.debug(f"Added to existing batch id={batch.id}")
    else:
        from app.db.models.item import Item
        from app.db.models.uom import UOM

        # Canonicalization: Find target UOM
        item = db.query(Item).filter(Item.id == entry.item_id).first()
        uom_code = None
        if item and item.default_uom_id:
            uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
            uom_code = uom.code if uom else None

        target_unit = uom_code if uom_code else entry.unit

        # Convert quantity if needed
        qty_to_store = Decimal(str(entry.quantity))

        # Strict Unit Validation
        if target_unit != entry.unit:
            try:
                factor = get_conversion_factor(
                    db, entry.item_id, entry.unit, target_unit
                )
                qty_to_store = qty_to_store * factor
                logger.info(
                    f"Canonicalizing stock: {entry.quantity} {entry.unit} -> {qty_to_store} {target_unit}"
                )
            except Exception as e:
                logger.error(f"Invalid unit for stock entry: {e}")
                raise AppException(
                    f"Invalid unit '{entry.unit}' for item. Must be convertible to '{target_unit}'",
                    status_code=400,
                )

        batch = Batch(
            item_id=entry.item_id,
            warehouse_id=resolved_warehouse_id,
            quantity=qty_to_store,
            unit=target_unit,
            received_at=entry.received_date,
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(batch)
        db.flush()
        logger.debug(
            f"Created new batch id={batch.id} (qty={batch.quantity} {batch.unit})"
        )

    # 2) Persist StockEntry
    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    stock_entry_data = entry.dict(exclude={"warehouse_id"})
    stock_entry = StockEntry(
        **stock_entry_data,
        batch_id=batch.id,
        warehouse_id=batch.warehouse_id,
        created_by=user_name,
        created_by_id=user_id,
        updated_by=user_name,
    )
    db.add(stock_entry)
    db.flush()
    db.refresh(stock_entry)
    logger.info(f"Created stock entry id={stock_entry.id}")

    # 3) Add InventoryTxn
    from app.db.models.item import Item

    item = db.get(Item, entry.item_id)
    if not item:
        logger.error(f"Item not found id={entry.item_id}")
        raise AppException("Item not found", status_code=404)

    if not item.default_uom_code:
        raise UOMConfigurationError(
            f"Item id={item.id} has no default UOM configured. Application cannot determine target unit for inventory ledger."
        )

    target_unit = item.default_uom_code

    try:
        factor = get_conversion_factor(db, entry.item_id, entry.unit, target_unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise

    base_qty = Decimal(str(entry.quantity)) * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=entry.item_id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=entry.quantity,
            raw_unit=entry.unit,
            base_qty=base_qty,
            base_unit=target_unit,
            ref_type="stock_entry",
            ref_id=stock_entry.id,
            remarks="Stock received",
        ),
    )
    db.flush()  # Ensure ID is generated before commit

    if idempotency_key:
        save_idempotency_record(
            db,
            idempotency_key,
            "create_stock_entry",
            entry.dict(),
            "stock_entry",
            stock_entry.id,
        )

    try:
        log_action(
            db=db,
            actor_user_id=user_id,
            action_type="stock_entry_created",
            entity_type="stock_entry",
            entity_id=stock_entry.id,
            metadata={
                "warehouse_id": resolved_warehouse_id,
                "batch_id": batch.id,
                "received_date": str(entry.received_date),
                "quantity": str(entry.quantity),
            },
        )
    except Exception:
        logger.warning("Audit log failed for stock_entry_created", exc_info=True)

    db.commit()
    return stock_entry


def get_stock_entry(
    db: Session, stock_entry_id: int, warehouse_id: Optional[int] = None
) -> Optional[StockEntry]:
    """
    Retrieve a stock entry by ID.

    Args:
        db (Session): Database session.
        stock_entry_id (int): Stock entry ID.

    Returns:
        Optional[StockEntry]: Stock entry or None.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Retrieving stock entry id={stock_entry_id}")
    q = db.query(StockEntry).filter(
        StockEntry.id == stock_entry_id,
        StockEntry.warehouse_id == resolved_warehouse_id,
    )
    return q.first()


def get_all_stock_entries(
    db: Session,
    warehouse_id: Optional[int] = None,
    date: Optional[date] = None,
    skip: int = 0,
    limit: int = 100,
) -> List[StockEntry]:
    """
    Retrieve stock entries with optional date filter.

    Args:
        db (Session): Database session.
        date (Optional[date]): Filter by date received.
        skip (int): Records to skip.
        limit (int): Max records to return.

    Returns:
        List[StockEntry]: List of entries.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.debug(f"Fetching stock entries date={date}, skip={skip}, limit={limit}")
    q = db.query(StockEntry).filter(
        StockEntry.is_active, StockEntry.warehouse_id == resolved_warehouse_id
    )
    if date:
        q = q.filter(StockEntry.received_date == date)
    return q.offset(skip).limit(limit).all()


def update_stock_entry(
    db: Session,
    stock_entry_id: int,
    entry_update: StockEntryUpdate,
    updated_by: Optional[int] = None,
) -> Optional[StockEntry]:
    """
    Update a stock entry.
    BLOCKED: Stock entries are now immutable.
    """
    logger.warning(f"Blocked update attempt on stock_entry_id={stock_entry_id}")
    raise AppException(
        "Stock entries are immutable. Use adjustment or reversal.", status_code=409
    )


def create_stock_adjustment(
    db: Session,
    batch_id: int,
    quantity_delta: Decimal,
    unit: str,
    reason: str,
    user_id: Optional[int] = None,
    warehouse_id: Optional[int] = None,
):
    try:
        return _create_stock_adjustment_impl(
            db, batch_id, quantity_delta, unit, reason, user_id, warehouse_id
        )
    except Exception:
        db.rollback()
        raise


def _create_stock_adjustment_impl(
    db: Session,
    batch_id: int,
    quantity_delta: Decimal,
    unit: str,
    reason: str,
    user_id: Optional[int] = None,
    warehouse_id: Optional[int] = None,
):
    """
    Create a stock adjustment (correction/drift fix).
    Directly impacts Batch and creates an 'ADJUST' InventoryTxn.
    Does NOT modify the original StockEntry receipt.
    """
    from datetime import datetime

    from app.db.models.item import Item
    from app.db.schemas.inventory_txn import InventoryTxnCreate
    from app.services.inventory_txn import create_inventory_txn

    logger.info(
        f"Creating stock adjustment batch_id={batch_id} delta={quantity_delta} ({unit})"
    )

    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    batch = (
        db.query(Batch)
        .filter(Batch.id == batch_id, Batch.warehouse_id == resolved_warehouse_id)
        .with_for_update()
        .first()
    )
    if not batch:
        raise AppException("Batch not found", status_code=404)
    enforce_lock_for_entity(db, batch, batch.created_at.date())

    item = db.get(Item, batch.item_id)
    if not item or not item.default_uom_code:
        raise UOMConfigurationError("Item or default UOM configuration missing")

    target_unit = item.default_uom_code

    # Calculate base qty
    try:
        factor = get_conversion_factor(db, item.id, unit, target_unit)
    except AppException:
        raise AppException(
            f"Cannot convert adjustment unit {unit} to base {target_unit}"
        )

    base_qty_delta = quantity_delta * factor

    # 0. Safety Check: Prevent negative stock
    if (batch.quantity + base_qty_delta) < 0:
        raise AppException(
            f"Adjustment blocked: Resulting quantity cannot be negative (Current: {batch.quantity}, Adjustment: {base_qty_delta})",
            status_code=400,
        )

    # 1. Update Batch (Cleanup Stage)
    batch.quantity += base_qty_delta
    batch.updated_by = user_id
    batch.updated_at = datetime.utcnow()

    # 2. Create Audit Txn
    txn = create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=item.id,
            batch_id=batch.id,
            txn_type="ADJUST",
            raw_qty=quantity_delta,
            raw_unit=unit,
            base_qty=base_qty_delta,
            base_unit=target_unit,
            ref_type="manual_adjustment",
            ref_id=batch.id,  # Link to batch as this is direct adjustment
            remarks=reason if reason else "Manual stock adjustment",
        ),
    )

    db.flush()

    try:
        log_action(
            db=db,
            actor_user_id=user_id,
            action_type="stock_adjustment_created",
            entity_type="inventory_txn",
            entity_id=txn.id,
            metadata={
                "warehouse_id": resolved_warehouse_id,
                "batch_id": batch_id,
                "quantity_delta": str(quantity_delta),
                "reason": reason,
            },
        )
    except Exception:
        logger.warning("Audit log failed for stock_adjustment_created", exc_info=True)

    db.commit()  # Commit immediately as this is an atomic action
    return txn


def delete_stock_entry(
    db: Session, stock_entry_id: int, warehouse_id: Optional[int] = None
) -> bool:
    try:
        return _delete_stock_entry_impl(db, stock_entry_id, warehouse_id)
    except Exception:
        db.rollback()
        raise


def _delete_stock_entry_impl(
    db: Session, stock_entry_id: int, warehouse_id: Optional[int] = None
) -> bool:
    """
    Delete a stock entry and adjust batch quantity.

    Args:
        db (Session): Database session.
        stock_entry_id (int): Stock entry ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    resolved_warehouse_id = resolve_system_warehouse_id(db, warehouse_id)
    logger.info(f"Deleting stock entry id={stock_entry_id}")
    entry = get_stock_entry(db, stock_entry_id, warehouse_id=resolved_warehouse_id)
    if not entry:
        logger.error(f"Stock entry not found id={stock_entry_id}")
        return False
    enforce_financial_lock(db, resolved_warehouse_id, entry.received_date)
    # Lock the batch before deletion to ensure safe quantity restore/check
    batch = (
        db.query(Batch)
        .filter(Batch.id == entry.batch_id, Batch.warehouse_id == resolved_warehouse_id)
        .with_for_update()
        .first()
    )

    # 0) Guardrail: Block if downstream dispatches or rejections exist for this batch
    from app.db.models.dispatch_entry import DispatchEntry
    from app.db.models.rejection_entry import RejectionEntry

    dispatch_exists = (
        db.query(DispatchEntry).filter(DispatchEntry.batch_id == entry.batch_id).first()
    )
    if dispatch_exists:
        logger.warning(
            f"Deletion blocked: Batch {entry.batch_id} has downstream dispatches"
        )
        raise AppException(
            f"Cannot delete stock entry. Batch {entry.batch_id} already has dispatches recorded. "
            "Deletion would orphan downstream transactions.",
            status_code=400,
        )

    rejection_exists = (
        db.query(RejectionEntry)
        .filter(
            RejectionEntry.batch_id == entry.batch_id,
            RejectionEntry.is_active,  # Only block if active rejections exist
        )
        .first()
    )
    if rejection_exists:
        logger.warning(
            f"Deletion blocked: Batch {entry.batch_id} has downstream rejections"
        )
        raise AppException(
            f"Cannot delete stock entry. Batch {entry.batch_id} already has rejections recorded. "
            "Deletion would orphan downstream transactions. Reverse rejections first.",
            status_code=400,
        )

    if batch:
        # Direct NUMERIC update (Stage 3: Cleanup)
        batch.quantity -= Decimal(str(entry.quantity))
        batch.updated_at = datetime.utcnow()
        batch.updated_by = entry.updated_by

    # Soft Delete: Mark as inactive instead of deleting
    entry.is_active = False
    db.flush()

    logger.debug(f"Stock entry id={stock_entry_id} soft-deleted (voided)")

    from app.db.models.item import Item

    item = db.get(Item, entry.item_id)

    if not item or not item.default_uom_code:
        raise UOMConfigurationError(f"Item id={item.id} has no default UOM configured.")
    target_unit = item.default_uom_code

    try:
        factor = get_conversion_factor(db, entry.item_id, entry.unit, target_unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise

    base_qty = Decimal(str(entry.quantity)) * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=entry.item_id,
            batch_id=entry.batch_id,
            txn_type="OUT",
            raw_qty=entry.quantity,
            raw_unit=entry.unit,
            base_qty=base_qty,
            base_unit=target_unit,
            ref_type="stock_entry",
            ref_id=entry.id,
            remarks="Stock removed via delete",
        ),
    )

    try:
        log_action(
            db=db,
            actor_user_id=entry.created_by_id,
            action_type="stock_entry_voided",
            entity_type="stock_entry",
            entity_id=entry.id,
            metadata={
                "warehouse_id": resolved_warehouse_id,
                "batch_id": entry.batch_id,
                "quantity": str(entry.quantity),
            },
        )
    except Exception:
        logger.warning("Audit log failed for stock_entry_voided", exc_info=True)

    db.commit()
    return True
