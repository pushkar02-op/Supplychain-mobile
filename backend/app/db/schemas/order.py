from datetime import date, datetime
from decimal import Decimal
from typing import Any, Optional

from app.db.schemas.base import SchemaModel
from app.db.schemas.item import ItemRead
from pydantic import model_validator


class OrderBase(SchemaModel):
    item_id: int
    warehouse_id: Optional[int] = None
    unit: str
    order_date: date
    quantity_ordered: Decimal  # Validation handled in service layer


class OrderCreate(OrderBase):
    mart_name: str


class OrderUpdate(SchemaModel):
    quantity_ordered: Optional[Decimal] = None
    # Updates to mart are typically restricted, but if needed, use mart_name
    mart_name: Optional[str] = None


class OrderRead(OrderBase):
    id: int
    warehouse_id: int
    mart_id: int
    mart_name: Optional[str] = None
    item: ItemRead
    unit: str
    quantity_dispatched: Decimal
    status: str
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    created_by: Optional[str]
    updated_by: Optional[str]

    class Config:
        from_attributes = True

    @model_validator(mode="before")
    @classmethod
    def set_mart_name(cls, data: Any) -> Any:
        # Auto-populate mart_name from ORM relationship if available
        if hasattr(data, "mart") and data.mart:
            try:
                data.mart_name = data.mart.name
            except AttributeError:
                pass
        return data
