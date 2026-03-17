from pydantic import BaseModel


class MartBase(BaseModel):
    name: str
    company_name: str
    is_active: bool = True


class MartCreate(MartBase):
    pass


class MartUpdate(BaseModel):
    name: str
    company_name: str


class MartStatusUpdate(BaseModel):
    is_active: bool


class MartRead(MartBase):
    id: int

    class Config:
        orm_mode = True
