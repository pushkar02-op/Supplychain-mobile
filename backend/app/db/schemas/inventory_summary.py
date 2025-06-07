from pydantic import BaseModel


class InventorySummaryRead(BaseModel):
    item_id: int
    item_name: str
    unit: str
    available_quantity: float

    class Config:
        from_attributes = True
