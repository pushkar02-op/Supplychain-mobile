from __future__ import annotations

from datetime import date

from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.reconciliation_record import DriftStatus, ReconciliationRecord
from app.db.models.user import User
from app.db.models.warehouse import Warehouse
from app.services.audit import log_action
from sqlalchemy import func
from sqlalchemy.orm import Session


def enforce_financial_lock(db: Session, warehouse_id: int, business_date: date) -> None:
    warehouse = db.get(Warehouse, warehouse_id)
    if not warehouse:
        raise AppException(
            status_code=404,
            detail="Warehouse not found",
            rule_id="AUT-004",
            metadata={"warehouse_id": warehouse_id},
        )

    lock_date = warehouse.financial_lock_date
    if lock_date is not None and business_date <= lock_date:
        raise AppException(
            status_code=400,
            detail="Financial period locked",
            rule_id="AUT-007",
            metadata={
                "warehouse_id": warehouse_id,
                "business_date": str(business_date),
                "financial_lock_date": str(lock_date),
            },
        )


def enforce_lock_for_entity(db: Session, entity: object, business_date: date) -> None:
    warehouse_id = getattr(entity, "warehouse_id", None)
    if warehouse_id is None:
        raise AppException(
            status_code=400,
            detail="Entity does not expose warehouse_id",
            rule_id="AUT-007",
            metadata={"entity_type": type(entity).__name__},
        )
    enforce_financial_lock(db, warehouse_id=warehouse_id, business_date=business_date)


def set_financial_lock(
    db: Session,
    warehouse_id: int,
    lock_date: date,
    actor_user: User,
) -> Warehouse:
    if actor_user.role != Role.OWNER:
        raise AppException(
            status_code=403,
            detail="Insufficient permissions",
            rule_id="AUT-001",
            metadata={
                "allowed_roles": [Role.OWNER.value],
                "user_role": actor_user.role.value,
            },
        )

    warehouse = db.get(Warehouse, warehouse_id)
    if not warehouse:
        raise AppException(
            status_code=404,
            detail="Warehouse not found",
            rule_id="AUT-004",
            metadata={"warehouse_id": warehouse_id},
        )

    if (
        warehouse.financial_lock_date is not None
        and lock_date < warehouse.financial_lock_date
    ):
        raise AppException(
            status_code=400,
            detail="Cannot move financial lock backward",
            rule_id="AUT-007",
            metadata={
                "warehouse_id": warehouse_id,
                "current_lock_date": str(warehouse.financial_lock_date),
                "requested_lock_date": str(lock_date),
            },
        )

    open_drift = (
        db.query(ReconciliationRecord)
        .filter(
            ReconciliationRecord.warehouse_id == warehouse_id,
            ReconciliationRecord.status == DriftStatus.OPEN,
            func.date(ReconciliationRecord.detected_at) <= lock_date,
        )
        .first()
    )
    if open_drift:
        raise AppException(
            status_code=400,
            detail="Cannot lock period with unresolved drift",
            rule_id="AUT-006",
            metadata={
                "warehouse_id": warehouse_id,
                "lock_date": str(lock_date),
                "open_record_id": open_drift.id,
            },
        )

    try:
        previous_lock_date = warehouse.financial_lock_date
        warehouse.financial_lock_date = lock_date
        db.flush()
        log_action(
            db=db,
            actor_user_id=actor_user.id,
            action_type="financial_lock_set",
            entity_type="warehouse",
            entity_id=warehouse_id,
            metadata={
                "previous_lock_date": (
                    str(previous_lock_date) if previous_lock_date else None
                ),
                "new_lock_date": str(lock_date),
            },
        )
        db.commit()
    except Exception:
        db.rollback()
        raise

    db.refresh(warehouse)
    return warehouse


def get_financial_lock(db: Session, warehouse_id: int) -> date | None:
    warehouse = db.get(Warehouse, warehouse_id)
    if not warehouse:
        raise AppException(
            status_code=404,
            detail="Warehouse not found",
            rule_id="AUT-004",
            metadata={"warehouse_id": warehouse_id},
        )
    return warehouse.financial_lock_date
