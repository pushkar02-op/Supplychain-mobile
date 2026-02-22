# backend/app/db/schemas/item_management.py

from decimal import Decimal
from typing import List, Optional

from app.db.schemas.base import SchemaModel


class UOMRead(SchemaModel):
    id: int
    code: str
    description: Optional[str]

    class Config:
        orm_mode = True


class ItemAliasInput(SchemaModel):
    id: Optional[int] = None
    alias_code: Optional[str]
    alias_name: str


class ConversionInput(SchemaModel):
    source_unit: str
    target_unit: str
    conversion_factor: Decimal


class ItemManagementCreateUpdate(SchemaModel):
    id: Optional[int] = None
    name: str
    default_uom_id: Optional[int]
    aliases: List[ItemAliasInput]
    conversions: List[ConversionInput]


class ItemAliasRead(SchemaModel):
    id: int
    alias_code: str
    alias_name: str

    class Config:
        from_attributes = True


class ItemConversionMapRead(SchemaModel):
    id: int
    source_unit: str
    target_unit: str
    conversion_factor: Decimal

    class Config:
        from_attributes = True


class ItemManagementRead(SchemaModel):
    id: int
    name: str
    default_uom_code: Optional[str]
    aliases: List[ItemAliasRead]
    conversions: List[ItemConversionMapRead]

    class Config:
        from_attributes = True


class AliasMapInput(SchemaModel):
    alias_id: int
    item_id: int
