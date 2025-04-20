from pydantic import BaseModel
from typing import Optional

class ItemBase(BaseModel):
    name: str
    default_unit: str

class ItemCreate(ItemBase):
    pass

class ItemUpdate(ItemBase):
    name: Optional[str] = None
    default_unit: Optional[str] = None

class ItemRead(ItemBase):
    id: int

    class Config:
        orm_mode = True
