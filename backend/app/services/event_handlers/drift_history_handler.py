from decimal import Decimal

from app.db.models.inventory_drift_history import InventoryDriftHistory
from app.db.schemas.domain_event import DomainEventBase
from app.domain.drift_policy import classify_drift_amount
from sqlalchemy.orm import Session


def handle_drift_history(session: Session, event: DomainEventBase):
    """
    Insert InventoryDriftHistory projection.
    """
    payload = event.payload
    drift = Decimal(str(payload.get("drift_resolved", 0)))
    batch_id = payload.get("batch_id")

    severity = classify_drift_amount(drift)

    history = InventoryDriftHistory(
        batch_id=batch_id,
        drift=drift,
        severity=severity,
        resolved_at=event.occurred_at,
        resolution_type="ADJUSTMENT",  # Default for now
    )
    session.add(history)
