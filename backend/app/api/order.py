"""
API endpoints for order management.
Provides CRUD operations and retrieval of distinct mart names.
"""

import logging
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date

from app.core.exceptions import AppException
from app.db.schemas.order import OrderCreate, OrderRead, OrderUpdate
from app.services.order import (
    create_order,
    get_order,
    get_orders,
    update_order,
    delete_order,
    get_distinct_mart_names,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post("/", response_model=OrderRead, status_code=status.HTTP_201_CREATED)
def create(entry: OrderCreate, db: Session = Depends(get_db)) -> OrderRead:
    """
    Create a new order.

    Args:
        entry (OrderCreate): Order data.
        db (Session): Database session dependency.

    Returns:
        OrderRead: The created order.
    """
    logger.info("Creating new order")
    return create_order(db=db, entry=entry, created_by="system")


@router.get("/", response_model=List[OrderRead], summary="List orders")
def read_all(
    order_date: Optional[date] = Query(None, description="Filter by order date"),
    mart_name: Optional[str] = Query(None, description="Filter by mart name"),
    db: Session = Depends(get_db),
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
    return get_orders(db=db, order_date=order_date, mart_name=mart_name)


@router.get("/mart-names", response_model=List[str], summary="List mart names")
def get_mart_names(db: Session = Depends(get_db)) -> List[str]:
    """
    Retrieve distinct mart names from orders.

    Args:
        db (Session): Database session dependency.

    Returns:
        List[str]: List of mart names.
    """
    logger.info("Fetching distinct mart names")
    return get_distinct_mart_names(db)


@router.get("/{order_id}", response_model=OrderRead, summary="Get order by ID")
def read_one(order_id: int, db: Session = Depends(get_db)) -> OrderRead:
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
    order = get_order(db=db, order_id=order_id)
    if not order:
        logger.error(f"Order not found: id={order_id}")
        raise AppException("Order not found", status_code=404)
    return order


@router.put("/{order_id}", response_model=OrderRead, summary="Update order")
def update(
    order_id: int, entry_update: OrderUpdate, db: Session = Depends(get_db)
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
    updated = update_order(
        db=db, order_id=order_id, entry_update=entry_update, updated_by="system"
    )
    if not updated:
        logger.error(f"Order not found: id={order_id}")
        raise AppException("Order not found", status_code=404)
    return updated


@router.delete(
    "/{order_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete order"
)
def delete(order_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete an order by ID.

    Args:
        order_id (int): Order ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If order not found (404).
    """
    logger.info(f"Deleting order id={order_id}")
    success = delete_order(db=db, order_id=order_id)
    if not success:
        logger.error(f"Order not found: id={order_id}")
        raise AppException("Order not found", status_code=404)
    return None
