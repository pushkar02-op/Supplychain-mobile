from datetime import date
from typing import List, Optional

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.cost_control import DailyCostRead, DailyCostUpsertRequest
from app.db.session import get_db
from app.services.cost_control import (
    get_labour_cost_range,
    get_transport_cost_range,
    upsert_labour_cost,
    upsert_transport_cost,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter(prefix="/cost", tags=["Cost Control"])


@router.post("/labour", response_model=DailyCostRead)
def upsert_labour(
    payload: DailyCostUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> DailyCostRead:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=payload.warehouse_id,
        db=db,
        operation_type="create",
    )
    record = upsert_labour_cost(
        db=db,
        warehouse_id=resolved_warehouse_id,
        date=payload.date,
        total_cost=payload.total_cost,
        user_id=current_user.id,
        notes=payload.notes,
    )
    return record


@router.post("/transport", response_model=DailyCostRead)
def upsert_transport(
    payload: DailyCostUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> DailyCostRead:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=payload.warehouse_id,
        db=db,
        operation_type="create",
    )
    record = upsert_transport_cost(
        db=db,
        warehouse_id=resolved_warehouse_id,
        date=payload.date,
        total_cost=payload.total_cost,
        user_id=current_user.id,
        notes=payload.notes,
    )
    return record


@router.get("/labour", response_model=List[DailyCostRead])
def list_labour(
    start_date: date = Query(...),
    end_date: date = Query(...),
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> List[DailyCostRead]:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="read",
    )
    return get_labour_cost_range(
        db=db,
        warehouse_id=resolved_warehouse_id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/transport", response_model=List[DailyCostRead])
def list_transport(
    start_date: date = Query(...),
    end_date: date = Query(...),
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> List[DailyCostRead]:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="read",
    )
    return get_transport_cost_range(
        db=db,
        warehouse_id=resolved_warehouse_id,
        start_date=start_date,
        end_date=end_date,
    )
