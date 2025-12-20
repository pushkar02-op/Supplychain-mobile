from datetime import date, datetime
from typing import Any, Optional

from app.db.schemas.item import ItemRead
from pydantic import BaseModel, model_validator


class OrderBase(BaseModel):
    item_id: int
    unit: str
    mart_id: int
    mart_name: Optional[str]
    order_date: date
    quantity_ordered: float


class OrderCreate(OrderBase):
    pass


class OrderUpdate(BaseModel):
    quantity_ordered: Optional[float] = None
    mart_id: Optional[int] = None


class OrderRead(OrderBase):
    id: int
    item: ItemRead
    unit: str
    quantity_dispatched: float
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
