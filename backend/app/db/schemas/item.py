from typing import Optional

from pydantic import BaseModel


class ItemBase(BaseModel):
    name: str
    item_code: str | None = None


class ItemCreate(ItemBase):
    default_unit: Optional[str] = None


class ItemUpdate(ItemBase):
    name: Optional[str] = None
    default_unit: Optional[str] = None


class ItemRead(ItemBase):
    id: int
    default_unit: Optional[str] = None

    class Config:
        from_attributes = True
