import asyncio
import logging

from app.core.structured_logging import log_event
from app.db.models.batch import Batch
from app.db.models.warehouse import Warehouse
from app.db.session import SessionLocal
from app.services.ledger_guard import check_inventory_drift, check_ledger_integrity
from sqlalchemy import text

logger = logging.getLogger(__name__)

_LEDGER_HEALTH_LOCK_ID = 987654321
_LEDGER_HEALTH_INTERVAL_SECONDS = 300


def run_ledger_health_monitor() -> None:
    db = SessionLocal()
    lock_acquired = False

    try:
        lock_acquired = bool(
            db.execute(
                text("SELECT pg_try_advisory_lock(:lock_id)"),
                {"lock_id": _LEDGER_HEALTH_LOCK_ID},
            ).scalar()
        )
        if not lock_acquired:
            return

        active_warehouse_ids = {
            warehouse_id
            for (warehouse_id,) in db.query(Warehouse.id)
            .filter(Warehouse.is_active.is_(True))
            .all()
        }

        drift_batches = [
            row
            for row in check_inventory_drift(db)
            if row.get("warehouse_id") in active_warehouse_ids
        ]
        invalid_refs = []
        for row in check_ledger_integrity(db):
            batch_id = row.get("batch_id")
            if batch_id is None:
                invalid_refs.append(row)
                continue

            batch = db.get(Batch, batch_id)
            if batch is None or batch.warehouse_id in active_warehouse_ids:
                invalid_refs.append(row)
        ledger_status = (
            "healthy" if not drift_batches and not invalid_refs else "unhealthy"
        )

        log_event(
            "info",
            "ledger_health_status",
            metadata={
                "ledger_status": ledger_status,
                "drift_batches": drift_batches,
                "invalid_refs": invalid_refs,
            },
        )
    except Exception:
        logger.exception("Ledger health monitor execution failed")
    finally:
        if lock_acquired:
            try:
                db.execute(
                    text("SELECT pg_advisory_unlock(:lock_id)"),
                    {"lock_id": _LEDGER_HEALTH_LOCK_ID},
                )
            except Exception:
                logger.exception(
                    "Ledger health monitor failed to release advisory lock"
                )
        db.close()


async def start_ledger_health_monitor() -> None:
    while True:
        try:
            run_ledger_health_monitor()
        except Exception:
            logger.exception("Ledger health monitor loop failed")
        await asyncio.sleep(_LEDGER_HEALTH_INTERVAL_SECONDS)
