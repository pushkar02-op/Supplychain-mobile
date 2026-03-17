"""
API endpoints for order management.
Provides CRUD operations and retrieval of distinct mart names.
"""

import logging
from datetime import date
from typing import List, Optional

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.order import OrderCreate, OrderRead, OrderUpdate
from app.db.session import get_db
from app.services.order import (
    create_order,
    delete_order,
    get_distinct_mart_names,
    get_order,
    get_orders,
    update_order,
)
from app.services.warehouse_scope import resolve_warehouse_for_request
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post("/", response_model=OrderRead, status_code=status.HTTP_201_CREATED)
def create(
    entry: OrderCreate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> OrderRead:
    """
    Create a new order.

    Args:
        entry (OrderCreate): Order data.
        db (Session): Database session dependency.

    Returns:
        OrderRead: The created order.
    """
    logger.info("Creating new order")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "create"
    )
    return create_order(
        db=db, entry=entry, created_by="system", warehouse_id=resolved_warehouse_id
    )


@router.get("/", response_model=List[OrderRead], summary="List orders")
def read_all(
    warehouse_id: Optional[int] = Query(None),
    order_date: Optional[date] = Query(None, description="Filter by order date"),
    mart_name: Optional[str] = Query(None, description="Filter by mart name"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> List[OrderRead]:
    """
    Retrieve orders with optional filters.

    Args:
        order_date (Optional[date]): Filter by date.
        mart_name (Optional[str]): Filter by mart.
        db (Session): Database session dependency.

    Returns:
        List[OrderRead]: List of orders.
    """
    logger.info(f"Fetching orders date={order_date}, mart={mart_name}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    orders = get_orders(
        db=db,
        warehouse_id=resolved_warehouse_id,
        order_date=order_date,
        mart_name=mart_name,
    )
    return orders


@router.get("/mart-names", response_model=List[dict], summary="List mart names")
def get_mart_names(
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> List[dict]:
    """
    Retrieve mart master records for order entry.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[dict]: List of mart IDs and names.
    """
    logger.info("Fetching distinct mart names")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    return get_distinct_mart_names(db, warehouse_id=resolved_warehouse_id)


@router.get("/{order_id}", response_model=OrderRead, summary="Get order by ID")
def read_one(
    order_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> OrderRead:
    """
    Retrieve a single order by ID.

    Args:
        order_id (int): Order ID.
        db (Session): Database session dependency.

    Returns:
        OrderRead: The order.

    Raises:
        AppException: If order not found (404).
    """
    logger.info(f"Fetching order id={order_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "read"
    )
    order = get_order(db=db, order_id=order_id, warehouse_id=resolved_warehouse_id)
    if not order:
        logger.error(f"Order not found: id={order_id}")
        raise AppException("Order not found", status_code=404)
    return order


@router.put("/{order_id}", response_model=OrderRead, summary="Update order")
def update(
    order_id: int,
    entry_update: OrderUpdate,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> OrderRead:
    """
    Update an existing order.

    Args:
        order_id (int): Order ID.
        entry_update (OrderUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        OrderRead: The updated order.

    Raises:
        AppException: If order not found (404).
    """
    logger.info(f"Updating order id={order_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "update"
    )
    updated = update_order(
        db=db,
        order_id=order_id,
        entry_update=entry_update,
        updated_by="system",
        warehouse_id=resolved_warehouse_id,
    )
    if not updated:
        logger.error(f"Order not found: id={order_id}")
        raise AppException("Order not found", status_code=404)
    return updated


@router.delete(
    "/{order_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete order"
)
def delete(
    order_id: int,
    warehouse_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.MANAGER, Role.OWNER)),
) -> None:
    """
    Delete an order by ID.

    Args:
        order_id (int): Order ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If order not found (404).
    """
    logger.info(f"Deleting order id={order_id}")
    resolved_warehouse_id = resolve_warehouse_for_request(
        current_user, warehouse_id, db, "delete"
    )
    success = delete_order(
        db=db,
        order_id=order_id,
        warehouse_id=resolved_warehouse_id,
        current_user_id=current_user.id,
    )
    if not success:
        logger.error(f"Order not found: id={order_id}")
        raise AppException("Order not found", status_code=404)
    return None
