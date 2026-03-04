from pydantic import BaseModel


class WarehouseAccessRead(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True
