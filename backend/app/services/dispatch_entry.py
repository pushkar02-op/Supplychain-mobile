"""
Service functions for dispatch entry management.
Handles creation from single entries or orders, and CRUD operations.
"""

import json
import logging
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

from app.core.decimal_utils import enforce_decimal
from app.core.exceptions import AppException
from app.core.structured_logging import log_event
from app.db.models.batch import Batch
from app.db.models.dispatch_entry import DispatchEntry
from app.db.models.dispatch_reversal import DispatchReversal
from app.db.models.domain_event import DomainEvent
from app.db.models.mart import Mart
from app.db.models.order import Order
from app.db.schemas.dispatch_entry import (
    DispatchEntryCreate,
    DispatchEntryMultiCreate,
    DispatchReversalCreate,
)
from app.db.schemas.domain_event import DispatchCompleted, OrderFulfilled
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.audit import log_action
from app.services.financial_lock import enforce_financial_lock, enforce_lock_for_entity
from app.services.inventory_txn import create_inventory_txn
from app.services.item_conversion_map import get_conversion_factor
from app.services.order import update_order_status_after_reversal
from app.utils.idempotency import check_idempotency, save_idempotency_record
from sqlalchemy import func, select
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_reversal_entry(
    db: Session,
    dispatch_id: int,
    entry: DispatchReversalCreate,
    created_by: Optional[str] = None,
    created_by_user_id: Optional[int] = None,
    warehouse_id: Optional[int] = None,
) -> DispatchReversal:
    """
    Create a reversal for a dispatch entry.
    Restores inventory and updates order status.

    Args:
        db (Session): Database session.
        dispatch_id (int): Dispatch ID to reverse.
        entry (DispatchReversalCreate): Reversal details.
        created_by (Optional[str]): Creator ID.

    Returns:
        DispatchReversal: Created reversal record.
    """
    logger.info(f"Creating reversal for dispatch {dispatch_id}")

    try:
        # 1. Fetch Dispatch
        dispatch = db.get(DispatchEntry, dispatch_id)
        if not dispatch:
            logger.error(f"Dispatch {dispatch_id} not found")
            raise AppException("Dispatch entry not found", status_code=404)
        if warehouse_id is not None and dispatch.warehouse_id != warehouse_id:
            raise AppException(
                "Unauthorized warehouse access",
                status_code=403,
                rule_id="AUT-004",
                metadata={"warehouse_id": warehouse_id},
            )
        enforce_lock_for_entity(db, dispatch, dispatch.dispatch_date)

        # 2. Calculate Remaining Quantity
        total_reversed = db.scalar(
            select(func.sum(DispatchReversal.quantity)).where(
                DispatchReversal.dispatch_entry_id == dispatch_id
            )
        ) or Decimal("0")

        # Use Decimal for precision
        dispatch_qty = Decimal(str(dispatch.quantity))
        existing_reversed = Decimal(str(total_reversed))
        remaining_qty = dispatch_qty - existing_reversed

        if remaining_qty <= 0:
            logger.warning(f"Dispatch {dispatch_id} is already fully reversed")
            raise AppException("Dispatch is already fully reversed", status_code=409)

        # 3. Determine Reversal Quantity
        if entry.quantity is None:
            reversal_qty = remaining_qty
        else:
            reversal_qty = Decimal(str(entry.quantity))

        if reversal_qty <= 0:
            raise AppException("Reversal quantity must be > 0", status_code=400)

        if reversal_qty > remaining_qty:
            logger.warning(
                f"Requested reversal {reversal_qty} > remaining {remaining_qty}"
            )
            raise AppException(
                f"Cannot reverse {reversal_qty}. Only {remaining_qty} remaining.",
                status_code=409,
            )

        # 4. Create Reversal Record
        reversal = DispatchReversal(
            dispatch_entry_id=dispatch_id,
            quantity=reversal_qty,
            reason=entry.reason,
            created_by=created_by,
            created_at=datetime.utcnow(),
        )
        db.add(reversal)

        # 5. Restore Inventory (Ledger IN)
        batch = db.get(Batch, dispatch.batch_id)

        # Canonical Conversion
        try:
            factor = Decimal(
                str(
                    get_conversion_factor(
                        db, dispatch.item_id, dispatch.unit, batch.unit
                    )
                )
            )
            canonical_qty = reversal_qty * factor
        except AppException as e:
            logger.error(f"Conversion failed for reversal: {e}")
            raise

        # Mutate Batch
        batch.quantity += canonical_qty
        batch.updated_at = datetime.utcnow()

        # Create Ledger Entry
        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=dispatch.item_id,
                batch_id=batch.id,
                txn_type="IN",
                raw_qty=reversal_qty,
                raw_unit=dispatch.unit,
                base_qty=canonical_qty,
                base_unit=batch.unit,
                ref_type="dispatch_reversal",  # New ref type? or dispatch_entry?
                # ref_type usually matches table name? usage in codebase implies strict strings
                # Let's use 'dispatch_reversal' to be clear, ensuring length fits (32 chars)
                ref_id=dispatch.id,  # Link to dispatch? Or reversal id?
                # Reversal ID isn't available until flush.
                # Using dispatch.id might confuse what the txn is for?
                # But ref_id usually links to the primary key of the *cause*.
                # We should flush reversal first.
                remarks=f"Reversal: {entry.reason or 'Manual correction'}",
            ),
            actor_user_id=created_by_user_id,
        )

        db.flush()
        db.refresh(reversal)  # Now we have ID

        # Update Ledger Ref ID to Reversal ID?
        # Actually, let's pass reversal.id if we flush first.
        # But wait, create_inventory_txn might flush too?
        # It seems okay.
        # Let's stick with ref_type='dispatch_reversal', ref_id=reversal.id
        # But we need to update the txn created above?
        # Or just flush before creating txn.

        # Find relevant order to update status
        # INTENT INTEGRITY: Prefer explicit link, fallback to heuristic
        order = None
        if dispatch.order_id:
            order = db.get(Order, dispatch.order_id)

        if not order:
            order = db.scalar(
                select(Order)
                .where(
                    Order.item_id == dispatch.item_id,
                    Order.mart_id == dispatch.mart_id,
                    Order.quantity_dispatched > 0,
                )
                .order_by(Order.order_date.desc())
                .limit(1)
            )

        if order:
            update_order_status_after_reversal(db, order, reversal_qty)
        else:
            logger.warning(
                f"No order found to credit reversal for dispatch {dispatch_id}"
            )

        if created_by_user_id is not None:
            log_action(
                db=db,
                actor_user_id=created_by_user_id,
                action_type="dispatch_reversed",
                entity_type="dispatch_reversal",
                entity_id=reversal.id,
                metadata={
                    "dispatch_entry_id": dispatch_id,
                    "warehouse_id": dispatch.warehouse_id,
                    "quantity": str(reversal_qty),
                },
            )
        db.commit()
        return reversal
    except Exception:
        db.rollback()
        raise


def create_dispatch_entry(
    db: Session,
    entry: DispatchEntryCreate,
    created_by: Optional[str] = None,
    warehouse_id: Optional[int] = None,
    idempotency_key: Optional[str] = None,
) -> DispatchEntry:
    try:
        return _create_dispatch_entry_impl(
            db, entry, created_by, warehouse_id, idempotency_key
        )
    except Exception:
        db.rollback()
        raise


def _create_dispatch_entry_impl(
    db: Session,
    entry: DispatchEntryCreate,
    created_by: Optional[str] = None,
    warehouse_id: Optional[int] = None,
    idempotency_key: Optional[str] = None,
) -> DispatchEntry:
    """
    Create a single dispatch entry, decrementing batch stock and updating order status.
    ENFORCEMENT:
    - INV-005: Canonical Normalization
    - NUM-001: Decimal Safety

    Args:
        db (Session): Database session.
        entry (DispatchEntryCreate): Dispatch data.
        created_by (Optional[str]): Creator identifier.

    Returns:
        DispatchEntry: The created dispatch record.

    Raises:
        AppException: On invalid batch, insufficient stock, or duplicate dispatch.
    """
    logger.info(
        f"Creating dispatch for batch_id={entry.batch_id}, qty={entry.quantity}"
    )
    payload = entry.dict(exclude_unset=True)
    if idempotency_key:
        existing_record = check_idempotency(
            db, idempotency_key, "dispatch_entry_create", payload
        )
        if existing_record:
            existing_entry = db.get(
                DispatchEntry, int(existing_record.result_entity_id)
            )
            if not existing_entry:
                raise AppException("Dispatch entry not found", status_code=404)
            return existing_entry
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).with_for_update().first()
    if not batch:
        logger.error("Invalid batch_id provided")
        raise AppException("Invalid batch_id provided", status_code=400)
    if warehouse_id is not None and batch.warehouse_id != warehouse_id:
        raise AppException(
            "Unauthorized warehouse access",
            status_code=403,
            rule_id="AUT-004",
            metadata={"warehouse_id": warehouse_id},
        )
    enforce_financial_lock(db, batch.warehouse_id, entry.dispatch_date)

    mart = db.scalar(select(Mart).where(Mart.name == entry.mart_name))
    if not mart:
        logger.error(f"Mart {entry.mart_name} not found")
        raise AppException(f"Mart {entry.mart_name} not found", status_code=404)

    # ====================================================================
    # ORD-007 ENFORCEMENT: Dispatch Must Respect Order Remaining Quantity
    # INTENT INTEGRITY: Prefer explicit order_id, fallback to heuristic.
    # ====================================================================
    order = None
    if entry.order_id:
        order = db.get(Order, entry.order_id)
        if not order:
            raise AppException(f"Order {entry.order_id} not found", status_code=404)
        if order.warehouse_id != batch.warehouse_id:
            raise AppException(
                "Unauthorized warehouse access",
                status_code=403,
                rule_id="AUT-004",
                metadata={"warehouse_id": order.warehouse_id},
            )
    else:
        # LEGACY PATH — DO NOT DEPEND ON FOR NEW FEATURES
        # Heuristic Fallback (Legacy): Implicit order linking when order_id not provided
        order = db.scalar(
            select(Order).where(
                Order.item_id == entry.item_id,
                Order.mart_id == mart.id,
                Order.warehouse_id == batch.warehouse_id,
                Order.status.notin_(["Cancelled", "Completed"]),
            )
        )
        if order:
            # Emit structured warning for legacy path observability (Phase 2B)
            logger.warning(
                "LEGACY_PATH_TRIGGERED: Implicit dispatch-order linking used",
                extra={
                    "rule_violation": "ORD-007",
                    "legacy_path": "implicit_dispatch_order_link",
                    "item_id": entry.item_id,
                    "mart_id": mart.id,
                    "linked_order_id": order.id,
                },
            )
    if order:
        existing_dispatched = Decimal(str(order.quantity_dispatched or 0))
        quantity_ordered = Decimal(str(order.quantity_ordered))
        dispatch_qty = Decimal(str(entry.quantity))
        remaining_qty = quantity_ordered - existing_dispatched

        if dispatch_qty > remaining_qty:
            logger.warning(
                f"ORD-007 BLOCKED: Dispatch {dispatch_qty} exceeds remaining {remaining_qty} "
                f"for order {order.id}"
            )
            raise AppException(
                message=f"Dispatch quantity ({dispatch_qty}) exceeds remaining order quantity ({remaining_qty}).",
                status_code=409,
                extra={
                    "rule_id": "ORD-007",
                    "requested_quantity": dispatch_qty,
                    "remaining_quantity": remaining_qty,
                    "explanation": "Over-dispatch is not allowed. Reduce quantity or create a new order.",
                },
            )

    # Check for dispatch against Cancelled/Completed orders
    blocked_order = db.scalar(
        select(Order).where(
            Order.item_id == entry.item_id,
            Order.mart_id == mart.id,
            Order.warehouse_id == batch.warehouse_id,
            Order.status.in_(["Cancelled", "Completed"]),
        )
    )
    if blocked_order and not order:
        # No active order, but a cancelled/completed one exists
        logger.warning(
            f"ORD-007 BLOCKED: Dispatch against {blocked_order.status} order {blocked_order.id}"
        )
        raise AppException(
            message=f"Cannot dispatch against {blocked_order.status} order.",
            status_code=409,
            extra={
                "rule_id": "ORD-007",
                "order_status": blocked_order.status,
                "explanation": f"Order is {blocked_order.status} and cannot receive dispatches.",
            },
        )
    # ====================================================================

    # 1) Normalize to Batch Unit (Canonical)
    # Batch is assumed/enforced to be in canonical unit by stock_entry logic.
    try:
        factor = Decimal(
            str(get_conversion_factor(db, entry.item_id, entry.unit, batch.unit))
        )
    except AppException as e:
        logger.error(f"Conversion failed for dispatch: {e}")
        raise

    raw_qty = Decimal(str(entry.quantity))
    canonical_qty = raw_qty * factor

    # 2) Validate Availability (Canonical vs Canonical)
    if batch.quantity < canonical_qty:
        msg = f"Not enough stock. Available: {batch.quantity} {batch.unit}, requested: {entry.quantity} {entry.unit} ({canonical_qty} {batch.unit})"
        logger.error(msg)
        raise AppException(msg, status_code=400)

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, created_by)
    user_id = user_id or 0

    dispatch = db.scalar(
        select(DispatchEntry).where(
            DispatchEntry.batch_id == entry.batch_id,
            DispatchEntry.mart_id == mart.id,
            DispatchEntry.dispatch_date == entry.dispatch_date,
        )
    )
    if dispatch:
        if order and dispatch.order_id and dispatch.order_id != order.id:
            raise AppException(
                "Dispatch entry already exists for a different order",
                status_code=409,
            )
        dispatch.quantity = Decimal(str(dispatch.quantity)) + raw_qty
        dispatch.unit = entry.unit
        dispatch.remarks = entry.remarks or dispatch.remarks
        dispatch.updated_by = user_name
        dispatch.updated_at = datetime.utcnow()
        if order and dispatch.order_id is None:
            dispatch.order_id = order.id
        db.add(dispatch)
        db.flush()
    else:
        dispatch = DispatchEntry(
            batch_id=entry.batch_id,
            item_id=entry.item_id,
            warehouse_id=batch.warehouse_id,
            mart_id=mart.id,
            dispatch_date=entry.dispatch_date,
            quantity=entry.quantity,  # Store raw user request
            unit=entry.unit,
            remarks=entry.remarks,
            created_by=user_name,
            created_by_id=user_id,
            updated_by=user_name,
            order_id=order.id if order else None,
        )
        db.add(dispatch)
        db.flush()

    # 3) Mutate Batch (Canonical)
    batch.quantity -= canonical_qty
    batch.updated_at = datetime.utcnow()

    # 4) Ledger OUT movement
    # Using the same calculated factor/canonical_qty ensures consistency
    try:
        create_inventory_txn(
            db,
            InventoryTxnCreate(
                item_id=entry.item_id,
                batch_id=entry.batch_id,
                txn_type="OUT",
                raw_qty=entry.quantity,
                raw_unit=entry.unit,
                base_qty=canonical_qty,
                base_unit=batch.unit,
                ref_type="dispatch_entry",
                ref_id=dispatch.id,
                remarks="Stock dispatched",
            ),
            actor_user_id=user_id,
        )
    except AppException as e:
        logger.error(f"Ledgering failed: {e}")
        raise

    _update_order_after_dispatch(
        db,
        entry.item_id,
        entry.mart_name,
        entry.quantity,
        warehouse_id=batch.warehouse_id,
        order_id=order.id if order else None,
    )
    db.flush()
    db.refresh(dispatch)
    logger.debug(f"Created/Updating dispatch record for item_id={entry.item_id}")

    # EMIT DOMAIN EVENT (Outbox)
    event_payload = DispatchCompleted(
        dispatch_id=dispatch.id,
        order_id=dispatch.order_id,
        item_id=dispatch.item_id,
        qty=dispatch.quantity,
    ).model_dump(mode="json")

    event = DomainEvent(
        event_type="dispatch.completed",
        aggregate_type="dispatch_entry",
        aggregate_id=str(dispatch.id),
        payload=event_payload,
    )
    db.add(event)

    try:
        log_action(
            db=db,
            actor_user_id=user_id,
            action_type="dispatch_created",
            entity_type="dispatch_entry",
            entity_id=dispatch.id,
            metadata={
                "warehouse_id": batch.warehouse_id,
                "batch_id": entry.batch_id,
                "dispatch_date": str(entry.dispatch_date),
                "quantity": str(entry.quantity),
            },
        )
    except Exception:
        logger.warning("Audit log failed for dispatch_created", exc_info=True)

    if idempotency_key:
        save_idempotency_record(
            db,
            idempotency_key,
            "dispatch_entry_create",
            payload,
            "dispatch_entry",
            str(dispatch.id),
        )

    db.commit()
    log_event(
        level="INFO",
        event="dispatch_created",
        metadata={"order_id": dispatch.order_id, "quantity": str(dispatch.quantity)},
    )
    logger.debug(f"Created dispatch id={dispatch.id}")
    return dispatch


def create_dispatch_from_order(
    db: Session,
    entry: DispatchEntryMultiCreate,
    created_by: Optional[str] = None,
    warehouse_id: Optional[int] = None,
    idempotency_key: Optional[str] = None,
) -> List[DispatchEntry]:
    try:
        return _create_dispatch_from_order_impl(
            db, entry, created_by, warehouse_id, idempotency_key
        )
    except Exception:
        db.rollback()
        raise


def _create_dispatch_from_order_impl(
    db: Session,
    entry: DispatchEntryMultiCreate,
    created_by: Optional[str] = None,
    warehouse_id: Optional[int] = None,
    idempotency_key: Optional[str] = None,
) -> List[DispatchEntry]:
    """
    Create dispatch entries from an order allocation across batches.
    ENFORCEMENT:
    - INV-005: Canonical Normalization
    - NUM-001: Decimal Safety

    Args:
        db (Session): Database session.
        entry (DispatchEntryMultiCreate): Multi-batch dispatch data.
        created_by (Optional[str]): Creator identifier.

    Returns:
        List[DispatchEntry]: All created/updated dispatch records.

    Raises:
        AppException: If no pending order or batch issues.
    """
    logger.info(f"Creating dispatches from order for item_id={entry.item_id}")
    payload = entry.dict(exclude_unset=True)
    if idempotency_key:
        existing_record = check_idempotency(
            db, idempotency_key, "dispatch_entry_from_order", payload
        )
        if existing_record:
            try:
                ids = json.loads(existing_record.result_entity_id)
            except Exception:
                raise AppException(
                    "Invalid idempotency record for dispatch bulk",
                    status_code=500,
                )
            if not isinstance(ids, list):
                raise AppException(
                    "Invalid idempotency record for dispatch bulk",
                    status_code=500,
                )
            results_by_id = {
                d.id: d
                for d in db.query(DispatchEntry).filter(DispatchEntry.id.in_(ids)).all()
            }
            ordered = [results_by_id[i] for i in ids if i in results_by_id]
            if len(ordered) != len(ids):
                raise AppException(
                    "Dispatch entries not found for idempotency hit",
                    status_code=404,
                )
            return ordered
    order = None
    if entry.order_id:
        order = db.get(Order, entry.order_id)
        if not order:
            raise AppException(f"Order {entry.order_id} not found", status_code=404)
        if warehouse_id is not None and order.warehouse_id != warehouse_id:
            raise AppException(
                "Unauthorized warehouse access",
                status_code=403,
                rule_id="AUT-004",
                metadata={"warehouse_id": warehouse_id},
            )
        if order.status == "Completed":
            # Optional: Allow dispatch against completed if strictly specified? No, usually forbidden.
            # But if user insists... No, logic below checks pending.
            pass
    else:
        stmt = (
            select(Order)
            .join(Mart)
            .where(
                Order.item_id == entry.item_id,
                Mart.name == entry.mart_name,
                Order.status != "Completed",
            )
        )
        if warehouse_id is not None:
            stmt = stmt.where(Order.warehouse_id == warehouse_id)
        order = db.scalar(stmt)
    if not order:
        msg = f"No pending order for item {entry.item_id} at mart {entry.mart_name}"
        logger.error(msg)
        raise AppException(msg, status_code=400)
    enforce_financial_lock(db, order.warehouse_id, entry.dispatch_date)

    total_req = sum(b.quantity for b in entry.batches)
    # 1) Deterministically lock all involved batches to prevent deadlocks
    params_batch_ids = sorted(list({b.batch_id for b in entry.batches}))

    batch_query = (
        db.query(Batch)
        .filter(Batch.id.in_(params_batch_ids))
        .filter(Batch.item_id == entry.item_id)
    )
    if warehouse_id is not None:
        batch_query = batch_query.filter(Batch.warehouse_id == warehouse_id)
    locked_batches = batch_query.order_by(Batch.id).with_for_update().all()

    batch_map = {b.id: b for b in locked_batches}

    # Verify all batches were found
    if len(batch_map) != len(params_batch_ids):
        found_ids = set(batch_map.keys())
        missing = set(params_batch_ids) - found_ids
        msg = f"Batches not found for item {entry.item_id}: {missing}"
        logger.error(msg)
        raise AppException(msg, status_code=404)

    results: List[DispatchEntry] = []

    # 2) Process each requested allocation using the locked batch objects
    for b in entry.batches:
        batch = batch_map[b.batch_id]

        # Canonical Normalization
        try:
            factor = Decimal(
                str(get_conversion_factor(db, entry.item_id, entry.unit, batch.unit))
            )
        except AppException as e:
            logger.error(f"Conversion failed for batch {batch.id}: {e}")
            raise

        raw_qty = Decimal(str(b.quantity))
        canonical_qty = raw_qty * factor

        if batch.quantity < canonical_qty:
            msg = f"Batch {b.batch_id} has only {batch.quantity} {batch.unit}, requested {b.quantity} {entry.unit} ({canonical_qty} {batch.unit})"
            logger.error(msg)
            raise AppException(msg, status_code=400)

        existing = db.scalar(
            select(DispatchEntry).where(
                DispatchEntry.batch_id == batch.id,
                DispatchEntry.mart_id == order.mart_id,
                DispatchEntry.dispatch_date == entry.dispatch_date,
            )
        )
        if existing:
            existing.quantity += b.quantity  # Raw update
            existing.remarks = entry.remarks or existing.remarks
            from app.utils.audit import resolve_user_audit

            user_name, user_id = resolve_user_audit(
                db, created_by
            )  # Treated as updated_by here
            user_id = user_id or 0
            existing.updated_by = user_name
            existing.updated_at = datetime.utcnow()
            db.add(existing)
            dispatch_record = existing
            db.flush()
            results.append(dispatch_record)
        else:
            from app.utils.audit import resolve_user_audit

            user_name, user_id = resolve_user_audit(db, created_by)
            user_id = user_id or 0

            dispatch_record = DispatchEntry(
                item_id=entry.item_id,
                batch_id=batch.id,
                warehouse_id=batch.warehouse_id,
                mart_id=order.mart_id,
                dispatch_date=entry.dispatch_date,
                quantity=b.quantity,  # Raw
                unit=entry.unit,
                remarks=entry.remarks,
                created_by=user_name,
                created_by_id=user_id,
                updated_by=user_name,
                order_id=order.id,
            )
            db.add(dispatch_record)
            db.flush()
            results.append(dispatch_record)

        # Mutate Batch (Canonical)
        batch.quantity -= canonical_qty
        batch.updated_at = datetime.utcnow()

        # 4) Ledger OUT movement for this batch
        try:
            # Factor already calculated
            # base_qty = canonical_qty (already calculated)

            create_inventory_txn(
                db,
                InventoryTxnCreate(
                    item_id=entry.item_id,
                    batch_id=batch.id,
                    txn_type="OUT",
                    raw_qty=b.quantity,
                    raw_unit=entry.unit,
                    base_qty=canonical_qty,
                    base_unit=batch.unit,
                    ref_type="dispatch_entry",
                    ref_id=dispatch_record.id,
                    remarks="Stock dispatched",
                ),
                actor_user_id=user_id,
            )
        except AppException as e:
            logger.error(f"Ledgering failed for batch {batch.id}: {e}")
            raise

    # 5) Finalize Order and Transactions
    _update_order_after_dispatch(
        db,
        entry.item_id,
        entry.mart_name,
        total_req,
        warehouse_id=warehouse_id,
        order_id=order.id,
    )
    db.flush()
    for d in results:
        db.refresh(d)

        # EMIT DOMAIN EVENT (Outbox)
        event_payload = DispatchCompleted(
            dispatch_id=d.id,
            order_id=d.order_id,
            item_id=d.item_id,
            qty=d.quantity,
        ).model_dump(mode="json")

        event = DomainEvent(
            event_type="dispatch.completed",
            aggregate_type="dispatch_entry",
            aggregate_id=str(d.id),
            payload=event_payload,
        )
        db.add(event)

    try:
        from app.utils.audit import resolve_user_audit

        _, actor_id = resolve_user_audit(db, created_by)
        actor_id = actor_id or 0
        for d in results:
            log_action(
                db=db,
                actor_user_id=actor_id,
                action_type="dispatch_created_from_order",
                entity_type="dispatch_entry",
                entity_id=d.id,
                metadata={
                    "warehouse_id": d.warehouse_id,
                    "order_id": order.id,
                    "dispatch_date": str(entry.dispatch_date),
                    "quantity": str(d.quantity),
                },
            )
    except Exception:
        logger.warning(
            "Audit log failed for dispatch_created_from_order", exc_info=True
        )

    if idempotency_key:
        save_idempotency_record(
            db,
            idempotency_key,
            "dispatch_entry_from_order",
            payload,
            "dispatch_entry_bulk",
            json.dumps([d.id for d in results]),
        )

    db.commit()
    logger.debug(f"Created/updated {len(results)} dispatch entries")
    return results


def _update_order_after_dispatch(
    db: Session,
    item_id: int,
    mart_name: str,
    dispatched_quantity: Decimal,
    warehouse_id: Optional[int] = None,
    order_id: Optional[int] = None,
) -> None:
    """
    Update the corresponding order’s dispatched quantity and status.
    Uses explicit order_id if provided, otherwise heuristically finds active order.

    Args:
        db (Session): Database session.
        item_id (int): Item ID.
        mart_name (str): Mart name.
        dispatched_quantity (Decimal): Quantity dispatched in this operation.
        order_id (Optional[int]): Explicit order ID.
    """
    if order_id:
        order = db.get(Order, order_id)
    else:
        stmt = (
            select(Order)
            .join(Mart)
            .where(
                Order.item_id == item_id,
                Mart.name == mart_name,
                Order.status != "Completed",
            )
        )
        if warehouse_id is not None:
            stmt = stmt.where(Order.warehouse_id == warehouse_id)
        order = db.scalar(stmt)

    if not order:
        return

    order.quantity_dispatched = Decimal(str(order.quantity_dispatched or 0)) + Decimal(
        str(dispatched_quantity)
    )
    order.status = (
        "Completed"
        if order.quantity_dispatched >= order.quantity_ordered
        else "Partially Completed"
    )
    order.updated_at = datetime.utcnow()
    db.add(order)
    db.flush()

    if order.status == "Completed":
        # EMIT DOMAIN EVENT (Outbox)
        event_payload = OrderFulfilled(
            order_id=order.id,
            item_id=order.item_id,
            mart_id=order.mart_id,
            total_qty=order.quantity_ordered,
        ).model_dump(mode="json")

        event = DomainEvent(
            event_type="order.fulfilled",
            aggregate_type="order",
            aggregate_id=str(order.id),
            payload=event_payload,
        )
        db.add(event)


def get_dispatch_entry(
    db: Session, dispatch_id: int, warehouse_id: Optional[int] = None
) -> Optional[DispatchEntry]:
    """
    Retrieve a dispatch entry by ID.

    Args:
        db (Session): Database session.
        dispatch_id (int): Dispatch entry ID.

    Returns:
        Optional[DispatchEntry]: The dispatch entry or None.
    """
    logger.debug(f"Retrieving dispatch id={dispatch_id}")
    q = db.query(DispatchEntry).filter(DispatchEntry.id == dispatch_id)
    if warehouse_id is not None:
        q = q.filter(DispatchEntry.warehouse_id == warehouse_id)
    return q.first()


def get_all_dispatch_entries(
    db: Session,
    warehouse_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    dispatch_date: Optional[date] = None,
    mart_name: Optional[str] = None,
    hide_fully_reversed: bool = False,
) -> List[DispatchEntry]:
    """
    Retrieve dispatch entries with optional filters and pagination.
    Returns DispatchEntry objects populated with 'net_quantity' and 'status'.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.
        dispatch_date (Optional[date]): Filter by date.
        mart_name (Optional[str]): Filter by mart name.
        hide_fully_reversed (bool): If True, exclude fully reversed entries (net_qty ~= 0).

    Returns:
        List[DispatchEntry]: List of dispatch entries with computed fields.
    """
    logger.debug(
        f"Fetching dispatches skip={skip}, limit={limit}, date={dispatch_date}, mart={mart_name}, hide_reversed={hide_fully_reversed}"
    )

    # Base query: DispatchEntry
    # We join with DispatchReversal to sum reversed quantities.
    # Group by DispatchEntry.id to aggregate reversals per dispatch.

    stmt = (
        select(
            DispatchEntry,
            func.coalesce(func.sum(DispatchReversal.quantity), Decimal("0")).label(
                "reversed_qty"
            ),
        )
        .outerjoin(
            DispatchReversal, DispatchReversal.dispatch_entry_id == DispatchEntry.id
        )
        .group_by(DispatchEntry.id)
    )
    if warehouse_id is not None:
        stmt = stmt.where(DispatchEntry.warehouse_id == warehouse_id)

    if dispatch_date:
        stmt = stmt.where(DispatchEntry.dispatch_date == dispatch_date)

    if mart_name:
        stmt = stmt.join(Mart, DispatchEntry.mart_id == Mart.id).where(
            Mart.name == mart_name
        )

    # Filter out fully reversed if requested
    if hide_fully_reversed:
        # HAVING (dispatch.quantity - summed_reversal) > 0
        # Use a small epsilon for float comparison safety or just > 0
        stmt = stmt.having(
            (
                DispatchEntry.quantity
                - func.coalesce(func.sum(DispatchReversal.quantity), Decimal("0"))
            )
            > 0
        )

    # Order by created_at desc

    # Order by created_at desc
    stmt = stmt.order_by(DispatchEntry.created_at.desc())

    # Pagination
    from app.utils.pagination import get_pagination_params

    offset, limit = get_pagination_params(skip=skip, limit=limit)
    stmt = stmt.offset(offset).limit(limit)

    results = db.execute(stmt).all()

    # Process results to attach computed fields
    final_list = []
    for row in results:
        dispatch = row[0]
        reversed_qty = row[1]

        # Calculate Net (Decimal arithmetic — G1 governance)
        net = enforce_decimal(dispatch.quantity) - enforce_decimal(reversed_qty)
        # Clamp to 0 just in case
        net = max(Decimal("0"), net)

        # Determine Status
        if net == enforce_decimal(dispatch.quantity):
            status = "Active"
        elif net == Decimal("0"):
            status = "Fully Reversed"
        else:
            status = "Partially Reversed"

        # Attach to object (runtime patch for Pydantic)
        setattr(dispatch, "net_quantity", net)
        setattr(dispatch, "status", status)

        final_list.append(dispatch)

    return final_list
