from pydantic import BaseModel
from typing import Optional


class ItemBase(BaseModel):
    name: str
    item_code: str | None = None


class ItemCreate(ItemBase):
    pass


class ItemUpdate(ItemBase):
    name: Optional[str] = None
    default_unit: Optional[str] = None


class ItemRead(ItemBase):
    id: int
    default_unit: Optional[str] = None

    class Config:
        from_attributes = True
