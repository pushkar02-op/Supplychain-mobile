from datetime import date

from pydantic import BaseModel


class WarehouseBase(BaseModel):
    name: str
    code: str
    is_active: bool = True


class WarehouseCreate(WarehouseBase):
    financial_lock_date: date | None = None


class WarehouseUpdate(WarehouseBase):
    financial_lock_date: date | None = None


class WarehouseRead(WarehouseBase):
    id: int
    financial_lock_date: date | None = None

    class Config:
        orm_mode = True
