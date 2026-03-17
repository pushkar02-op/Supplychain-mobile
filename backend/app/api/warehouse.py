from app.core.auth import get_current_user, require_role
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.warehouse import WarehouseCreate, WarehouseRead, WarehouseUpdate
from app.db.schemas.warehouse_access import WarehouseAccessRead
from app.db.schemas.warehouse_lock import WarehouseLockRead, WarehouseLockSetRequest
from app.db.session import get_db
from app.services.financial_lock import get_financial_lock, set_financial_lock
from app.services.warehouse import create_warehouse, list_warehouses, update_warehouse
from app.services.warehouse_scope import (
    list_accessible_warehouses,
    resolve_warehouse_for_request,
)
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter(prefix="/warehouses", tags=["Warehouses"])


@router.get("/", response_model=list[WarehouseRead])
def list_all_warehouses(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> list[WarehouseRead]:
    results = list_warehouses(db)
    return results[skip : skip + limit]


@router.post("/", response_model=WarehouseRead)
def create_new_warehouse(
    payload: WarehouseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> WarehouseRead:
    return create_warehouse(db, payload)


@router.put("/{warehouse_id}", response_model=WarehouseRead)
def update_existing_warehouse(
    warehouse_id: int,
    payload: WarehouseUpdate,
    current_session_warehouse: int | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> WarehouseRead:
    return update_warehouse(
        db,
        warehouse_id,
        payload,
        current_session_warehouse_id=current_session_warehouse,
    )


@router.get("/my-access", response_model=list[WarehouseAccessRead])
def get_my_accessible_warehouses(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[WarehouseAccessRead]:
    results = list_accessible_warehouses(current_user, db)
    return results[skip : skip + limit]


@router.post("/{warehouse_id}/lock", response_model=WarehouseLockRead)
def set_warehouse_financial_lock(
    warehouse_id: int,
    payload: WarehouseLockSetRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> WarehouseLockRead:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="update",
    )
    warehouse = set_financial_lock(
        db=db,
        warehouse_id=resolved_warehouse_id,
        lock_date=payload.lock_date,
        actor_user=current_user,
    )
    return WarehouseLockRead(
        warehouse_id=warehouse.id,
        financial_lock_date=warehouse.financial_lock_date,
    )


@router.patch("/{warehouse_id}/lock", response_model=WarehouseLockRead)
def patch_warehouse_financial_lock(
    warehouse_id: int,
    payload: WarehouseLockSetRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> WarehouseLockRead:
    return set_warehouse_financial_lock(warehouse_id, payload, db, current_user)


@router.get("/{warehouse_id}/lock", response_model=WarehouseLockRead)
def get_warehouse_financial_lock(
    warehouse_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> WarehouseLockRead:
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user=current_user,
        warehouse_id=warehouse_id,
        db=db,
        operation_type="read",
    )
    lock_date = get_financial_lock(db=db, warehouse_id=resolved_warehouse_id)
    return WarehouseLockRead(
        warehouse_id=resolved_warehouse_id,
        financial_lock_date=lock_date,
    )
