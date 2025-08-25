from pydantic import BaseModel


class MartBase(BaseModel):
    name: str
    company_name: str


class MartCreate(MartBase):
    pass


class MartRead(MartBase):
    id: int

    class Config:
        orm_mode = True
