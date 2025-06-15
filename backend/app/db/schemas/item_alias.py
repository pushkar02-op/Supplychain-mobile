from pydantic import BaseModel
from typing import Optional


class ItemAliasBase(BaseModel):
    alias: str


class ItemAliasCreate(ItemAliasBase):
    item_id: int


class ItemAliasRead(ItemAliasBase):
    id: int
    item_id: int

    class Config:
        orm_mode = True


class ItemAliasUpdate(BaseModel):
    master_item_id: Optional[int]
    alias_code: Optional[str]
    alias_name: Optional[str]
    alias_unit: Optional[str]
