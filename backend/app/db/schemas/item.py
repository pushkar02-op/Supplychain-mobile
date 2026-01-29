from typing import Optional

from app.db.models.item import ItemStatus
from pydantic import BaseModel


class ItemBase(BaseModel):
    name: str
    item_code: str | None = None


class ItemCreate(ItemBase):
    default_unit: Optional[str] = None
    creation_intent: Optional[str] = None  # "REGULAR" | "ONE_OFF"


class ItemUpdate(ItemBase):
    name: Optional[str] = None
    default_unit: Optional[str] = None
    creation_intent: Optional[str] = None


class ItemRead(ItemBase):
    id: int
    default_unit: Optional[str] = None
    creation_intent: Optional[str] = None
    status: ItemStatus = ItemStatus.ACTIVE

    class Config:
        from_attributes = True
