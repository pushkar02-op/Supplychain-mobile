from pydantic import BaseModel
from typing import Optional


class ItemAliasBase(BaseModel):
    alias_code: Optional[str]
    alias_name: Optional[str]


class ItemAliasCreate(ItemAliasBase):
    master_item_id: int


class ItemAliasRead(ItemAliasBase):
    id: int
    master_item_id: int

    class Config:
        orm_mode = True


class ItemAliasUpdate(BaseModel):
    alias_code: Optional[str]
    alias_name: Optional[str]
    item_id: Optional[int]
