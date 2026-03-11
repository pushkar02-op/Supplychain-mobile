from app.core.exceptions import AppException
from app.db.models.warehouse import Warehouse
from app.db.schemas.warehouse import WarehouseCreate, WarehouseUpdate
from sqlalchemy.orm import Session


def list_warehouses(db: Session) -> list[Warehouse]:
    return db.query(Warehouse).order_by(Warehouse.name.asc()).all()


def create_warehouse(db: Session, data: WarehouseCreate) -> Warehouse:
    warehouse = Warehouse(
        name=data.name,
        code=data.code,
        is_active=data.is_active,
        financial_lock_date=data.financial_lock_date,
    )
    db.add(warehouse)
    db.commit()
    db.refresh(warehouse)
    return warehouse


def update_warehouse(
    db: Session,
    warehouse_id: int,
    data: WarehouseUpdate,
    current_session_warehouse_id: int | None = None,
) -> Warehouse:
    warehouse = db.query(Warehouse).filter(Warehouse.id == warehouse_id).first()
    if not warehouse:
        raise AppException(detail="Warehouse not found", status_code=404)

    is_deactivation = warehouse.is_active and not data.is_active
    if is_deactivation:
        if current_session_warehouse_id == warehouse_id:
            raise AppException(
                detail="Cannot deactivate the currently active warehouse",
                status_code=409,
            )

        active_count = db.query(Warehouse).filter(Warehouse.is_active.is_(True)).count()
        if active_count == 1:
            raise AppException(
                detail="At least one active warehouse must exist",
                status_code=409,
            )

    warehouse.name = data.name
    warehouse.code = data.code
    warehouse.is_active = data.is_active
    warehouse.financial_lock_date = data.financial_lock_date
    db.commit()
    db.refresh(warehouse)
    return warehouse
