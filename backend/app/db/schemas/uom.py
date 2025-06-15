from pydantic import BaseModel


class UOMBase(BaseModel):
    code: str
    description: str | None = None


class UOMCreate(UOMBase): ...


class UOMRead(UOMBase):
    id: int

    class Config:
        orm_mode = True
