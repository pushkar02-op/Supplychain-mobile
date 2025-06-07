from pydantic import BaseModel
from typing import Optional


class ItemConversionBase(BaseModel):
    source_item_id: int
    target_item_id: int
    conversion_factor: float
    source_unit: str
    target_unit: str


class ItemConversionCreate(ItemConversionBase):
    pass


class ItemConversionUpdate(BaseModel):
    conversion_factor: Optional[float]
    source_unit: Optional[str]
    target_unit: Optional[str]


class ItemConversionRead(ItemConversionBase):
    id: int

    class Config:
        orm_mode = True
