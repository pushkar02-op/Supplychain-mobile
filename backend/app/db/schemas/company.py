from pydantic import BaseModel
from typing import Optional


class CompanyBase(BaseModel):
    name: str


class CompanyCreate(CompanyBase):
    pass


class CompanyRead(CompanyBase):
    id: int

    class Config:
        orm_mode = True
