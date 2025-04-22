from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from app.db.models.user import User
from app.db.schemas.user import UserUpdate

def get_user(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()

def get_all_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    return db.query(User).offset(skip).limit(limit).all()

def update_user(
    db: Session,
    user_id: int,
    user_update: UserUpdate,
    updated_by: Optional[str] = None
) -> Optional[User]:
    user = get_user(db, user_id)
    if not user:
        return None
    for key, val in user_update.dict(exclude_unset=True).items():
        setattr(user, key, val)
    user.updated_by = updated_by
    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    return user

def delete_user(db: Session, user_id: int) -> bool:
    user = get_user(db, user_id)
    if not user:
        return False
    db.delete(user)
    db.commit()
    return True
