from app.db.enums.role import Role
from pydantic import BaseModel


class UserCreate(BaseModel):
    username: str
    full_name: str
    password: str

    class Config:
        orm_mode = True


class UserLogin(BaseModel):
    username: str
    password: str

    class Config:
        orm_mode = True


class Token(BaseModel):
    access_token: str
    token_type: str
    role: Role
    is_admin: bool = False
    refresh_token: str
    user_id: int


class TokenRefresh(BaseModel):
    refresh_token: str
