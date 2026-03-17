from pydantic import BaseModel


class WarehouseAccessRead(BaseModel):
    id: int
    name: str
    code: str

    class Config:
        from_attributes = True
