from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.services.auth import register_user, login_user
from app.db.schemas.auth import UserCreate, UserLogin, Token
from app.db.session import get_db

router = APIRouter()

@router.post("/register", response_model=Token)  # ✅ Fix here
def register(user: UserCreate, db: Session = Depends(get_db)):
    return register_user(db, user)

@router.post("/login", response_model=Token)  # ✅ Fix here
def login(user: UserLogin, db: Session = Depends(get_db)):
    return login_user(db, user)
