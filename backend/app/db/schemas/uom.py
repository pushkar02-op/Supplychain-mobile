from pydantic import BaseModel


class UOMBase(BaseModel):
    code: str
    description: str | None = None
    is_active: bool = True


class UOMCreate(UOMBase): ...


class UOMUpdate(BaseModel):
    code: str
    description: str | None = None
    is_active: bool = True


class UOMRead(UOMBase):
    id: int

    class Config:
        orm_mode = True
