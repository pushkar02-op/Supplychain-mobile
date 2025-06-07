from datetime import datetime
from pydantic import BaseModel
from typing import Optional


class UserBase(BaseModel):
    username: str
    full_name: str
    is_admin: bool
    is_active: bool


class UserRead(UserBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True


class UserUpdate(BaseModel):
    full_name: Optional[str]
    is_admin: Optional[bool]
    is_active: Optional[bool]
