# backend/app/db/schemas/item_management.py

from pydantic import BaseModel
from typing import List, Optional


class UOMRead(BaseModel):
    id: int
    code: str
    description: Optional[str]

    class Config:
        orm_mode = True


class ItemAliasInput(BaseModel):
    id: Optional[int] = None
    alias_code: Optional[str]
    alias_name: str


class ConversionInput(BaseModel):
    source_unit: str
    target_unit: str
    conversion_factor: float


class ItemManagementCreateUpdate(BaseModel):
    id: Optional[int] = None
    name: str
    default_uom_id: Optional[int]
    aliases: List[ItemAliasInput]
    conversions: List[ConversionInput]


class ItemAliasRead(BaseModel):
    id: int
    alias_code: str
    alias_name: str

    class Config:
        from_attributes = True


class ItemConversionMapRead(BaseModel):
    id: int
    source_unit: str
    target_unit: str
    conversion_factor: float

    class Config:
        from_attributes = True


class ItemManagementRead(BaseModel):
    id: int
    name: str
    default_uom_code: Optional[str]
    aliases: List[ItemAliasRead]
    conversions: List[ItemConversionMapRead]

    class Config:
        from_attributes = True


class AliasMapInput(BaseModel):
    alias_id: int
    item_id: int
