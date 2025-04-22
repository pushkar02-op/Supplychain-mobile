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

