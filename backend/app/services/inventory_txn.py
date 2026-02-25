import logging
from decimal import ROUND_HALF_UP, Decimal
from typing import List, Optional

from app.core.exceptions import AppException
from app.db.models.batch import Batch
from app.db.models.domain_event import DomainEvent
from app.db.models.inventory_txn import InventoryTxn
from app.db.schemas.domain_event import InventoryTxnCommitted
from app.db.schemas.inventory_txn import InventoryTxnCreate
from app.services.audit import log_action
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def create_inventory_txn(db: Session, data: InventoryTxnCreate) -> InventoryTxn:
    # ENFORCEMENT: NUM-001 Ledger Storage Precision
    # Quantize to 3 decimal places to match Numeric(10,3) schema
    # Use ROUND_HALF_UP to ensure consistent behavior
    quantized_raw = Decimal(str(data.raw_qty)).quantize(
        Decimal("0.001"), rounding=ROUND_HALF_UP
    )
    quantized_base = Decimal(str(data.base_qty)).quantize(
        Decimal("0.001"), rounding=ROUND_HALF_UP
    )

    # Derive warehouse provenance from authoritative parent entities.
    warehouse_id = None
    if data.batch_id is not None:
        batch = db.get(Batch, data.batch_id)
        if not batch:
            raise AppException(
                "Batch not found for inventory transaction", status_code=404
            )
        warehouse_id = batch.warehouse_id
        if data.warehouse_id is not None and data.warehouse_id != warehouse_id:
            raise AppException(
                "Inventory transaction warehouse mismatch with batch",
                status_code=409,
                rule_id="INV-001",
                metadata={
                    "batch_id": data.batch_id,
                    "batch_warehouse_id": batch.warehouse_id,
                    "provided_warehouse_id": data.warehouse_id,
                },
            )
    else:
        warehouse_id = data.warehouse_id

    if warehouse_id is None:
        raise AppException(
            "warehouse_id is required for inventory transactions",
            status_code=400,
        )

    # Update data object with quantized values
    txn_data = data.dict()
    txn_data["raw_qty"] = quantized_raw
    txn_data["base_qty"] = quantized_base
    txn_data["warehouse_id"] = warehouse_id

    txn = InventoryTxn(**txn_data)
    db.add(txn)
    db.flush()
    db.refresh(txn)

    # EMIT DOMAIN EVENT (Outbox Pattern)
    event_payload = InventoryTxnCommitted(
        txn_id=txn.id,
        item_id=txn.item_id,
        batch_id=txn.batch_id,
        qty=txn.raw_qty,
        unit=txn.raw_unit,
        txn_type=txn.txn_type,
    ).model_dump(mode="json")

    event = DomainEvent(
        event_type="inventory_txn.committed",
        aggregate_type="inventory_txn",
        aggregate_id=str(txn.id),
        payload=event_payload,
    )
    db.add(event)
    # Commit happens at caller level or via FastAPI dependency
    logger.info(f"InventoryTxn created: {txn}")

    try:
        log_action(
            db=db,
            actor_user_id=None,
            action_type="inventory_txn_created",
            entity_type="inventory_txn",
            entity_id=txn.id,
            metadata={
                "warehouse_id": txn.warehouse_id,
                "ref_type": txn.ref_type,
                "ref_id": txn.ref_id,
            },
        )
    except Exception:
        logger.warning("Audit log failed for inventory_txn_created", exc_info=True)

    return txn


def get_inventory_txns(
    db: Session,
    item_id: int,
    warehouse_id: int,
    unit: Optional[str] = None,
    limit: int = 10,
) -> List[InventoryTxn]:
    """
    Fetch recent inventory transactions for an item (optionally filtered by unit).
    """
    q = db.query(InventoryTxn).filter(
        InventoryTxn.item_id == item_id,
        InventoryTxn.warehouse_id == warehouse_id,
    )
    if unit:
        q = q.filter(InventoryTxn.raw_unit == unit)
    q = q.order_by(InventoryTxn.created_at.desc()).limit(limit)
    return q.all()
