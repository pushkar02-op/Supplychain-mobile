from datetime import date

from pydantic import BaseModel


class WarehouseLockSetRequest(BaseModel):
    lock_date: date


class WarehouseLockRead(BaseModel):
    warehouse_id: int
    financial_lock_date: date | None
