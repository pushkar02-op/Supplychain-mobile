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
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy import and_
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_stock_entry(
    db: Session,
    entry: StockEntryCreate,
    created_by: Optional[int] = None,
    idempotency_key: Optional[str] = None,
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

    if idempotency_key:
        from app.utils.idempotency import check_idempotency, save_idempotency_record

        existing_record = check_idempotency(
            db, idempotency_key, "create_stock_entry", entry.dict()
        )
        if existing_record:
            return get_stock_entry(db, existing_record.result_entity_id)

    # 1) Find-or-create Batch
    batch = (
        db.query(Batch)
        .filter(
            and_(
                Batch.item_id == entry.item_id,
                Batch.received_at == entry.received_date,
            )
        )
        .with_for_update()
        .first()
    )

    if batch:
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

        unit = uom_code if uom_code else entry.unit

        batch = Batch(
            item_id=entry.item_id,
            quantity=Decimal(str(entry.quantity)),  # Direct NUMERIC (Stage 3)
            unit=unit,
            received_at=entry.received_date,
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(batch)
        db.flush()
        logger.debug(f"Created new batch id={batch.id}")

    # 2) Persist StockEntry
    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)

    stock_entry = StockEntry(
        **entry.dict(),
        batch_id=batch.id,
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

    db.commit()
    return stock_entry


def get_stock_entry(db: Session, stock_entry_id: int) -> Optional[StockEntry]:
    """
    Retrieve a stock entry by ID.

    Args:
        db (Session): Database session.
        stock_entry_id (int): Stock entry ID.

    Returns:
        Optional[StockEntry]: Stock entry or None.
    """
    logger.debug(f"Retrieving stock entry id={stock_entry_id}")
    return db.query(StockEntry).filter(StockEntry.id == stock_entry_id).first()


def get_all_stock_entries(
    db: Session, date: Optional[date] = None, skip: int = 0, limit: int = 100
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
    logger.debug(f"Fetching stock entries date={date}, skip={skip}, limit={limit}")
    q = db.query(StockEntry)
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
    Update a stock entry, adjusting batch allocations if needed.

    Args:
        db (Session): Database session.
        stock_entry_id (int): Stock entry ID.
        entry_update (StockEntryUpdate): Fields to update.
        updated_by (Optional[int]): Updater ID.

    Returns:
        Optional[StockEntry]: Updated entry or None.
    """
    logger.info(f"Updating stock entry id={stock_entry_id}")
    entry = get_stock_entry(db, stock_entry_id)
    if not entry:
        logger.error(f"Stock entry not found id={stock_entry_id}")
        return None

    orig_qty = entry.quantity
    # Lock the batch for update to ensure quantity consistency
    orig_batch = (
        db.query(Batch).filter(Batch.id == entry.batch_id).with_for_update().first()
    )
    data = entry_update.dict(exclude_unset=True)
    new_qty = data.get("quantity", entry.quantity)

    quantity_diff = new_qty - orig_qty
    if orig_batch:
        # Direct NUMERIC update (Stage 3: Cleanup)
        orig_batch.quantity += Decimal(str(quantity_diff))
        orig_batch.updated_by = updated_by
        orig_batch.updated_at = datetime.utcnow()

    for k, v in data.items():
        setattr(entry, k, v)
    entry.updated_by = updated_by
    entry.updated_at = datetime.utcnow()
    db.flush()
    db.refresh(entry)
    logger.debug(f"Stock entry id={stock_entry_id} updated")

    if quantity_diff != 0:
        txn_type = "IN" if quantity_diff > 0 else "OUT"

        from app.db.models.item import Item

        item = db.get(Item, entry.item_id)
        if not item:
            raise AppException("Item not found", status_code=404)

        if not item or not item.default_uom_code:
            raise UOMConfigurationError(
                f"Item id={item.id} has no default UOM configured."
            )
        target_unit = item.default_uom_code

        try:
            factor = get_conversion_factor(db, entry.item_id, entry.unit, target_unit)
        except AppException as e:
            logger.error(f"Conversion lookup failed: {e}")
            raise

        base_qty = Decimal(str(abs(quantity_diff))) * factor

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=entry.item_id,
                batch_id=entry.batch_id,
                txn_type=txn_type,
                raw_qty=abs(quantity_diff),
                raw_unit=entry.unit,
                base_qty=base_qty,
                base_unit=target_unit,
                ref_type="stock_entry",
                ref_id=entry.id,
                remarks=f"Stock {txn_type} from update adjustment",
            ),
        )
    db.commit()
    return entry


def delete_stock_entry(db: Session, stock_entry_id: int) -> bool:
    """
    Delete a stock entry and adjust batch quantity.

    Args:
        db (Session): Database session.
        stock_entry_id (int): Stock entry ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting stock entry id={stock_entry_id}")
    entry = get_stock_entry(db, stock_entry_id)
    if not entry:
        logger.error(f"Stock entry not found id={stock_entry_id}")
        return False

    # Lock the batch before deletion to ensure safe quantity restore/check
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).with_for_update().first()

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
        .filter(RejectionEntry.batch_id == entry.batch_id)
        .first()
    )
    if rejection_exists:
        logger.warning(
            f"Deletion blocked: Batch {entry.batch_id} has downstream rejections"
        )
        raise AppException(
            f"Cannot delete stock entry. Batch {entry.batch_id} already has rejections recorded. "
            "Deletion would orphan downstream transactions.",
            status_code=400,
        )

    if batch:
        # Direct NUMERIC update (Stage 3: Cleanup)
        batch.quantity -= Decimal(str(entry.quantity))
        batch.updated_at = datetime.utcnow()
        batch.updated_by = entry.updated_by
        batch.updated_by = entry.updated_by
    db.delete(entry)
    db.flush()
    logger.debug(f"Stock entry id={stock_entry_id} deleted")

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
    db.commit()
    return True
