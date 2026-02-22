from decimal import Decimal
from typing import Optional

from app.db.schemas.base import SchemaModel


class ItemConversionBase(SchemaModel):
    item_id: int
    source_unit: str
    target_unit: str
    conversion_factor: Decimal


class ItemConversionCreate(ItemConversionBase):
    pass


class ItemConversionUpdate(SchemaModel):
    conversion_factor: Optional[Decimal]
    source_unit: Optional[str]
    target_unit: Optional[str]


class ItemConversionRead(ItemConversionBase):
    id: int

    class Config:
        orm_mode = True
