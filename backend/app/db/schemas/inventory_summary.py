from pydantic import BaseModel


class InventorySummaryRead(BaseModel):
    item_id: int
    name: str
    unit: str
    current_stock: float

    class Config:
        from_attributes = True
