from pydantic import BaseModel
from typing import Optional


class ItemBase(BaseModel):
    name: str
    default_uom_id: int
    item_code: str | None = None


class ItemCreate(ItemBase):
    pass


class ItemUpdate(ItemBase):
    name: Optional[str] = None
    default_uom_id: Optional[int] = None


class ItemRead(ItemBase):
    id: int

    class Config:
        orm_mode = True
