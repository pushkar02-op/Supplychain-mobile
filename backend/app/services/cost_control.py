from __future__ import annotations

from datetime import date, datetime
from decimal import ROUND_HALF_UP, Decimal
from typing import List

from app.db.models.labour_cost_daily import LabourCostDaily
from app.db.models.transport_cost_daily import TransportCostDaily
from app.services.audit import log_action
from sqlalchemy.orm import Session


def _quantize_cost(value: Decimal) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)


def upsert_labour_cost(
    db: Session,
    warehouse_id: int,
    date: date,
    total_cost: Decimal,
    user_id: int | None,
    notes: str | None = None,
) -> LabourCostDaily:
    try:
        record = (
            db.query(LabourCostDaily)
            .filter(
                LabourCostDaily.warehouse_id == warehouse_id,
                LabourCostDaily.date == date,
            )
            .with_for_update()
            .first()
        )

        if record:
            record.total_cost = _quantize_cost(total_cost)
            record.notes = notes
            record.created_by = user_id
            record.updated_at = datetime.utcnow()
            action_type = "labour_cost_updated"
        else:
            record = LabourCostDaily(
                warehouse_id=warehouse_id,
                date=date,
                total_cost=_quantize_cost(total_cost),
                notes=notes,
                created_by=user_id,
            )
            db.add(record)
            action_type = "labour_cost_created"

        db.flush()
        if user_id is not None:
            log_action(
                db=db,
                actor_user_id=user_id,
                action_type=action_type,
                entity_type="labour_cost_daily",
                entity_id=record.id,
                metadata={"warehouse_id": warehouse_id, "date": str(date)},
            )
        db.commit()
        db.refresh(record)
        return record
    except Exception:
        db.rollback()
        raise


def upsert_transport_cost(
    db: Session,
    warehouse_id: int,
    date: date,
    total_cost: Decimal,
    user_id: int | None,
    notes: str | None = None,
) -> TransportCostDaily:
    try:
        record = (
            db.query(TransportCostDaily)
            .filter(
                TransportCostDaily.warehouse_id == warehouse_id,
                TransportCostDaily.date == date,
            )
            .with_for_update()
            .first()
        )

        if record:
            record.total_cost = _quantize_cost(total_cost)
            record.notes = notes
            record.created_by = user_id
            record.updated_at = datetime.utcnow()
            action_type = "transport_cost_updated"
        else:
            record = TransportCostDaily(
                warehouse_id=warehouse_id,
                date=date,
                total_cost=_quantize_cost(total_cost),
                notes=notes,
                created_by=user_id,
            )
            db.add(record)
            action_type = "transport_cost_created"

        db.flush()
        if user_id is not None:
            log_action(
                db=db,
                actor_user_id=user_id,
                action_type=action_type,
                entity_type="transport_cost_daily",
                entity_id=record.id,
                metadata={"warehouse_id": warehouse_id, "date": str(date)},
            )
        db.commit()
        db.refresh(record)
        return record
    except Exception:
        db.rollback()
        raise


def get_labour_cost_range(
    db: Session, warehouse_id: int, start_date: date, end_date: date
) -> List[LabourCostDaily]:
    return (
        db.query(LabourCostDaily)
        .filter(
            LabourCostDaily.warehouse_id == warehouse_id,
            LabourCostDaily.date >= start_date,
            LabourCostDaily.date <= end_date,
        )
        .order_by(LabourCostDaily.date.asc())
        .all()
    )


def get_transport_cost_range(
    db: Session, warehouse_id: int, start_date: date, end_date: date
) -> List[TransportCostDaily]:
    return (
        db.query(TransportCostDaily)
        .filter(
            TransportCostDaily.warehouse_id == warehouse_id,
            TransportCostDaily.date >= start_date,
            TransportCostDaily.date <= end_date,
        )
        .order_by(TransportCostDaily.date.asc())
        .all()
    )
