"""
Service functions for reporting.
Handles inventory and P&L summary retrieval from materialized views.
"""

import logging
from decimal import Decimal
from typing import List, Optional

from app.db.models.batch import Batch
from app.db.models.inventory_txn import InventoryTxn
from app.db.models.views.inventory_signal import InventorySignal
from app.db.models.views.inventory_summary import InventorySummary
from app.db.models.views.pnl_summary import PnlSummary
from app.db.schemas.inventory_summary import (
    InventorySummaryRead,
    ReconciliationBatch,
    ReconciliationDetail,
    ReconciliationItem,
    ReconciliationTxn,
)
from app.db.schemas.pnl_summary import PnlSummaryRead
from app.services.item_conversion_map import get_conversion_factor
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def get_inventory_report(
    db: Session, item_id: Optional[int]
) -> List[InventorySummaryRead]:
    """
    Retrieve inventory summary report, optionally filtered by item.

    Args:
        db (Session): Database session.
        item_id (Optional[int]): Filter by item ID.

    Returns:
        List[InventorySummaryRead]: Inventory summary data.
    """
    logger.info(f"Fetching inventory report for item_id={item_id}")
    q = db.query(InventorySummary)
    if item_id:
        q = q.filter(InventorySummary.item_id == item_id)
    results = q.all()
    logger.debug(f"Retrieved {len(results)} inventory records")
    results = q.all()
    logger.debug(f"Retrieved {len(results)} inventory records")

    # Fetch available quantities from Batch table

    from app.db.models.batch import Batch
    from sqlalchemy import func

    batch_q = db.query(
        Batch.item_id, Batch.unit, func.sum(Batch.quantity).label("total_qty")
    ).group_by(Batch.item_id, Batch.unit)

    if item_id:
        batch_q = batch_q.filter(Batch.item_id == item_id)

    batch_sums = batch_q.all()

    # Map item_id -> available_stock (normalized to default UOM)
    # Note: InventorySummary view already normalized to 'unit' (which is default UOM via join)
    # We must normalize batch sums to the SAME unit used in InventorySummary

    for b_item_id, b_unit, b_qty in batch_sums:
        # We need to normalize this b_qty to the item's default UOM
        # But we don't have the target unit handy in this loop easily without join
        # For performance, let's assume we can get target unit from the results list if present.
        # OR better: iterate results, query batches for that item, normalize and sum.
        # Given low volume, iterating results is safer for correctness.
        pass

    final_list = []

    # Map item_id -> available_stock
    item_available_map = {}
    for r in results:
        # Default to 0
        item_available_map[r.item_id] = 0.0

    # Batch Query for Available Stock
    batches = (
        db.query(Batch).filter(Batch.item_id.in_([r.item_id for r in results])).all()
    )

    # Pre-fetch conversion factors if possible, or query individually (caching helps)
    # Optimizing: Group batches by item
    batches_by_item = {}
    for b in batches:
        if b.item_id not in batches_by_item:
            batches_by_item[b.item_id] = []
        batches_by_item[b.item_id].append(b)

    for r in results:
        total_available = Decimal(0)
        if r.item_id in batches_by_item:
            for b in batches_by_item[r.item_id]:
                try:
                    factor = Decimal(
                        str(get_conversion_factor(db, r.item_id, b.unit, r.unit))
                    )
                    total_available += b.quantity * factor
                except Exception:
                    pass
        item_available_map[r.item_id] = float(total_available)

    # Signal Calculation via Read Model
    sig_q = db.query(InventorySignal).filter(
        InventorySignal.item_id.in_([r.item_id for r in results])
    )
    signals_data = sig_q.all()

    out_last_7d = {s.item_id: float(s.out_last_7d or 0) for s in signals_data}
    out_prev_7d = {s.item_id: float(s.out_prev_7d or 0) for s in signals_data}

    final_list = []
    for r in results:
        # Create display object from view
        # We handle mapping manually to satisfy the new truth model
        avail = item_available_map.get(r.item_id, 0.0)
        ledger = float(r.current_stock)

        # Drift Calculation
        delta = avail - ledger
        status = "HEALTHY"
        severity = "NONE"

        if abs(delta) > 0.001:
            status = "DRIFT"
            # Severity Logic
            denom = abs(ledger) if ledger != 0 else 1.0
            drift_ratio = abs(delta) / denom
            if ledger < 0 or drift_ratio > 0.05:
                severity = "CRITICAL"
            else:
                severity = "MAJOR"

        # Signals
        signals = []
        l7 = out_last_7d.get(r.item_id, 0.0)
        p7 = out_prev_7d.get(r.item_id, 0.0)

        # Fast Depletion
        if l7 > (p7 * 1.5) and l7 > 0:
            signals.append("FAST_DEPLETING")

        # Low Stock
        threshold = 10.0
        if l7 > 0:
            threshold = l7 * 0.2

        if avail <= threshold and avail > 0:
            signals.append("LOW_STOCK")

        if not signals and abs(delta) < 0.001 and avail > 0:
            signals.append("STABLE")

        display_obj = InventorySummaryRead(
            item_id=r.item_id,
            name=r.name,
            unit=r.unit,
            ledger_qty=ledger,
            state_qty=avail,
            status=status,
            severity=severity,
            signals=signals,
        )
        final_list.append(display_obj)

    return final_list


def get_reconciliation_report(db: Session) -> List[ReconciliationItem]:
    """
    Get detailed reconciliation report using Phase 5 Reconciliation Service.
    Standardized Logic.
    """
    from app.services.reconciliation import get_ledger_health_report

    # get_ledger_health_report returns standardized dicts now
    data = get_ledger_health_report(db)

    recon_items = []
    for d in data:
        recon_items.append(
            ReconciliationItem(
                item_id=d["item_id"],
                item_name=d["item_name"],
                state_qty=d["state_qty"],
                ledger_qty=d["ledger_qty"],
                drift=d["drift"],
                status=d["status"].upper(),
                severity=d["severity"],
            )
        )

    return recon_items


def get_item_reconciliation(
    db: Session, item_id: int
) -> Optional[ReconciliationDetail]:
    # 1. Get Basic Stats
    report_list = get_reconciliation_report(db)
    target = next((x for x in report_list if x.item_id == item_id), None)

    if not target:
        return None

    # 2. Get Item Summary (for full object)
    summary_list = get_inventory_report(db, item_id)
    if not summary_list:
        return None
    summary = summary_list[0]

    # 3. Recent Transactions (Last 20)
    txns = (
        db.query(InventoryTxn)
        .filter(InventoryTxn.item_id == item_id)
        .order_by(InventoryTxn.created_at.desc())
        .limit(20)
        .all()
    )
    recon_txns = []
    for t in txns:
        recon_txns.append(
            ReconciliationTxn(
                type=t.txn_type,
                qty=t.base_qty,
                ref=f"{t.ref_type}#{t.ref_id}" if t.ref_id else t.ref_type,
                created_at=str(t.created_at),
            )
        )

    # 4. Batch Snapshot
    batches = db.query(Batch).filter(Batch.item_id == item_id).all()
    recon_batches = []
    for b in batches:
        recon_batches.append(
            ReconciliationBatch(
                batch_id=b.id, qty=b.quantity, received_at=str(b.received_at)
            )
        )

    return ReconciliationDetail(
        item=summary,
        state_qty=target.state_qty,
        ledger_qty=target.ledger_qty,
        drift=target.drift,
        severity=target.severity,
        recent_transactions=recon_txns,
        batch_snapshot=recon_batches,
    )


def get_item_signals(db: Session, item_id: int):
    """
    Retrieve signal breakdown for a specific item.
    """

    from app.db.models.batch import Batch
    from app.db.models.views.inventory_summary import InventorySummary
    from app.db.schemas.inventory_summary import InventorySignalResponse

    # 1. Available Stock from Batches
    batches = db.query(Batch).filter(Batch.item_id == item_id).all()
    inv_summary = (
        db.query(InventorySummary).filter(InventorySummary.item_id == item_id).first()
    )

    if not inv_summary:
        return None  # Item not found

    total_available = Decimal(0)
    for b in batches:
        try:
            factor = Decimal(
                str(get_conversion_factor(db, item_id, b.unit, inv_summary.unit))
            )
            total_available += b.quantity * factor
        except Exception:
            pass

    available_stock = float(total_available)

    # 2. Transaction Aggregation via Read Model
    from app.db.models.views.inventory_signal import InventorySignal

    sig = db.get(InventorySignal, item_id)

    out_last_7d = (
        Decimal(str(sig.out_last_7d)) if sig and sig.out_last_7d else Decimal("0.0")
    )
    out_prev_7d = (
        Decimal(str(sig.out_prev_7d)) if sig and sig.out_prev_7d else Decimal("0.0")
    )

    # 3. Signals
    signals = []

    # Fast Depletion: Last 7d > Prev 7d * 1.5
    if out_last_7d > (out_prev_7d * Decimal("1.5")) and out_last_7d > 0:
        signals.append("FAST_DEPLETING")

    # Low Stock
    threshold = Decimal("10.0")
    if out_last_7d > 0:
        threshold = out_last_7d * Decimal("0.2")

    if available_stock <= threshold and available_stock > 0:
        signals.append("LOW_STOCK")

    if (
        not signals
        and abs(available_stock - inv_summary.current_stock) < 0.001
        and available_stock > 0
    ):
        signals.append("STABLE")

    avg_daily_outflow = out_last_7d / Decimal("7.0")

    return InventorySignalResponse(
        available_stock=available_stock,
        avg_daily_outflow=avg_daily_outflow,
        out_last_7d=out_last_7d,
        out_prev_7d=out_prev_7d,
        signals=signals,
    )


def get_pnl_report(
    db: Session, start: Optional[str], end: Optional[str]
) -> List[PnlSummaryRead]:
    """
    Retrieve profit & loss summary report between dates.

    Args:
        db (Session): Database session.
        start (Optional[str]): Start date YYYY-MM-DD.
        end (Optional[str]): End date YYYY-MM-DD.

    Returns:
        List[PnlSummaryRead]: P&L summary data.
    """
    logger.info(f"Fetching P&L report from {start} to {end}")
    q = db.query(PnlSummary)
    if start:
        q = q.filter(PnlSummary.date >= start)
    if end:
        q = q.filter(PnlSummary.date <= end)
    results = q.all()
    logger.debug(f"Retrieved {len(results)} P&L records")
    return [PnlSummaryRead.from_orm(r) for r in results]
