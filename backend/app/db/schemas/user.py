from datetime import datetime
from typing import Optional

from app.db.enums.role import Role
from pydantic import BaseModel


class UserBase(BaseModel):
    username: str
    full_name: str
    role: Role
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
    is_active: Optional[bool]


class UserRoleUpdate(BaseModel):
    role: Role


class UserCreateGoverned(BaseModel):
    username: str
    full_name: str
    password: str
    role: Role


class UserWarehouseAccessRead(BaseModel):
    warehouse_id: int
    warehouse_name: str
    warehouse_code: str
