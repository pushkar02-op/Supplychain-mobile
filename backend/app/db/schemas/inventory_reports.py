from app.db.schemas.base import SchemaModel


class TopMovingItem(SchemaModel):
    item_id: int
    item_name: str
    total_out: float
