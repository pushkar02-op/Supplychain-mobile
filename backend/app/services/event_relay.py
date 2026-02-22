import logging
from datetime import datetime

from app.core.structured_logging import log_event
from app.db.models.domain_event import DomainEvent
from app.services.event_handlers.drift_history_handler import handle_drift_history
from app.services.event_handlers.inventory_flow_handler import handle_inventory_flow
from app.services.event_handlers.order_metrics_handler import handle_order_metrics
from sqlalchemy import select
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

EVENT_HANDLERS = {
    "inventory_txn.committed": handle_inventory_flow,
    "reconciliation.resolved": handle_drift_history,
    "order.fulfilled": handle_order_metrics,
}


def process_pending_events(db: Session, batch_size: int = 50):
    try:
        return _process_pending_events_impl(db, batch_size)
    except Exception:
        db.rollback()
        raise


def _process_pending_events_impl(db: Session, batch_size: int = 50):
    """
    Polls for unprocessed domain events and dispatches them to handlers.

    Args:
        db (Session): Database session.
        batch_size (int): Max events to process in one run.

    Returns:
        int: Number of events processed.
    """
    # Fetch pending events
    # Use skip_locked for simplistic concurrency safety (though strictly single-threaded relay implied)
    query = (
        select(DomainEvent)
        .where(DomainEvent.processed_at.is_(None))
        .order_by(DomainEvent.occurred_at)
        .limit(batch_size)
        .with_for_update(skip_locked=True)
    )

    events = db.execute(query).scalars().all()
    count = 0

    for event in events:
        handler = EVENT_HANDLERS.get(event.event_type)

        try:
            if handler:
                logger.info(f"Processing event {event.id} ({event.event_type})")

                # Handlers assume they can use the session to write projections
                # Handlers MUST NOT commit; the relay commits.
                handler(db, event)
            else:
                logger.warning(
                    f"No handler for event {event.id} ({event.event_type}). Skipping."
                )

            # Mark processed
            event.processed_at = datetime.utcnow()
            log_event(
                level="INFO",
                event="domain_event_emitted",
                metadata={"event_type": event.event_type},
            )
            count += 1

        except Exception as e:
            logger.error(f"Failed to process event {event.id}: {e}")
            # In a real system, we might set a 'retry_count' or 'failed_at'.
            # For this strict phase, we leave it NULL (processed_at=None) so it retries next loop?
            # Constraint: "No retries logic beyond deterministic loop".
            # If it fails deterministically, it will block the queue.
            # We will LEAVE it as unprocessed so it is visible as 'stuck'.
            # We break/rollback this single event?
            # Since we are iterating, if we don't catch, the whole batch fails.
            # We caught it. The `event.processed_at` assignment is skipped.
            # We continue to next event?
            # But the session might be dirty?
            # If handler did partial write and crashed, session is invalid?
            # Ideally each iteration should be a savepoint (nested transaction).
            # But simpler: if exception, re-raise or logging?
            # I will re-raise to be safe and stop processing (letting outer scope handle connection reset).
            # Or assume pure handlers failing means Bad Data.
            raise e

    # Commit the batch progress
    # "Mark processed_at ONLY AFTER successful handling"
    # If we made it here, all `count` events are marked.
    db.commit()

    return count
