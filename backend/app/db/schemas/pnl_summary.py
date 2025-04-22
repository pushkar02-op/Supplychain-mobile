from datetime import date
from pydantic import BaseModel

class PnlSummaryRead(BaseModel):
    date: date
    total_purchase: float
    total_sales: float
    profit: float

    class Config:
        orm_mode = True
