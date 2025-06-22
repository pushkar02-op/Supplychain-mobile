"""
Service functions for stock entry management.
Handles receiving and adjustment of stock entries and underlying batches.
"""

import logging
from datetime import date, datetime
from typing import List, Optional

from sqlalchemy import and_
from sqlalchemy.orm import Session
from app.db.models.uom import UOM
from app.core.exceptions import AppException
from app.db.models.stock_entry import StockEntry
from app.db.models.batch import Batch
from app.db.models.item import Item
from app.db.schemas.stock_entry import StockEntryCreate, StockEntryUpdate
from app.services.inventory_txn import create_inventory_txn
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.item_conversion_map import get_conversion_factor

logger = logging.getLogger(__name__)


def create_stock_entry(
    db: Session, entry: StockEntryCreate, created_by: Optional[int] = None
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
        f"Creating stock entry for item_id={entry.item_id}, qty={entry.quantity}"
    )

    # 1) Find-or-create Batch
    batch = (
        db.query(Batch)
        .filter(
            and_(
                Batch.item_id == entry.item_id,
                Batch.received_at == entry.received_date,
            )
        )
        .first()
    )

    if batch:
        batch.quantity += entry.quantity
        batch.updated_by = created_by
        batch.updated_at = datetime.utcnow()
        db.commit()
        db.flush()
        logger.debug(f"Added to existing batch id={batch.id}")
    else:
        # item = db.query(Item).filter(Item.id == entry.item_id).first()
        # uom_code = None
        # if item and item.default_uom_id:

        # uom = db.query(UOM).filter(UOM.id == item.default_uom_id).first()
        # uom_code = uom.code if uom else None
        # unit = uom_code if uom_code else entry.unit
        batch = Batch(
            item_id=entry.item_id,
            quantity=entry.quantity,
            unit=entry.unit,
            received_at=entry.received_date,
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(batch)
        db.flush()
        logger.debug(f"Created new batch id={batch.id}")

    # 2) Persist StockEntry
    stock = StockEntry(
        **entry.dict(), batch_id=batch.id, created_by=created_by, updated_by=created_by
    )
    db.add(stock)
    db.commit()
    db.refresh(stock)
    logger.info(f"Created stock entry id={stock.id}")

    # 3) Add InventoryTxn
    #    — use `batch.unit` and `batch.id` no matter which branch we hit
    try:
        factor = get_conversion_factor(db, entry.item_id, entry.unit, batch.unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise

    base_qty = entry.quantity * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=entry.item_id,
            batch_id=batch.id,
            txn_type="IN",
            raw_qty=entry.quantity,
            raw_unit=entry.unit,
            base_qty=base_qty,
            base_unit=batch.unit,
            ref_type="stock_entry",
            ref_id=stock.id,
            remarks="Stock received",
        ),
    )

    return stock


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
    orig_batch = db.query(Batch).filter(Batch.id == entry.batch_id).first()
    data = entry_update.dict(exclude_unset=True)
    new_qty = data.get("quantity", entry.quantity)

    quantity_diff = new_qty - orig_qty
    if orig_batch:
        orig_batch.quantity += quantity_diff
        orig_batch.updated_by = updated_by
        orig_batch.updated_at = datetime.utcnow()

    for k, v in data.items():
        setattr(entry, k, v)
    entry.updated_by = updated_by
    entry.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(entry)
    logger.debug(f"Stock entry id={stock_entry_id} updated")

    if quantity_diff != 0:
        txn_type = "IN" if quantity_diff > 0 else "OUT"
        # compute factor & base_qty
        try:
            factor = get_conversion_factor(
                db, entry.item_id, entry.unit, orig_batch.unit
            )
        except AppException as e:
            logger.error(f"Conversion lookup failed: {e}")
            raise

        base_qty = abs(quantity_diff) * factor

        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=entry.item_id,
                batch_id=entry.batch_id,
                txn_type=txn_type,
                raw_qty=abs(quantity_diff),
                raw_unit=entry.unit,
                base_qty=base_qty,
                base_unit=orig_batch.unit,
                ref_type="stock_entry",
                ref_id=entry.id,
                remarks=f"Stock {txn_type} from update adjustment",
            ),
        )
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

    batch = db.query(Batch).filter(Batch.id == entry.batch_id).first()
    if batch:
        batch.quantity -= entry.quantity
        batch.updated_at = datetime.utcnow()
        batch.updated_by = entry.updated_by
    db.delete(entry)
    db.commit()
    logger.debug(f"Stock entry id={stock_entry_id} deleted")

    try:
        factor = get_conversion_factor(db, entry.item_id, entry.unit, entry.unit)
    except AppException as e:
        logger.error(f"Conversion lookup failed: {e}")
        raise

    base_qty = entry.quantity * factor

    create_inventory_txn(
        db,
        InventoryTxnCreate(
            item_id=entry.item_id,
            batch_id=entry.batch_id,
            txn_type="IN",
            raw_qty=entry.quantity,
            raw_unit=entry.unit,
            base_qty=base_qty,
            base_unit=entry.unit,
            ref_type="stock_entry",
            ref_id=entry.id,
            remarks=f"Stock added due to delete",
        ),
    )
    return True
