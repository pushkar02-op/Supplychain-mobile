from app.core.exceptions import AppException
from app.core.security import verify_access_token
from app.db.models.user import User
from app.db.session import get_db
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = AppException(
        status_code=401,
        detail="Could not validate credentials",
        metadata={"headers": {"WWW-Authenticate": "Bearer"}},
    )
    payload = verify_access_token(token)
    username: str = payload.get("sub")
    if username is None:
        raise credentials_exception
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise credentials_exception
    return user


def get_current_active_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    if not current_user.is_active:
        raise AppException(status_code=400, detail="Inactive user")
    if not current_user.is_admin:
        raise AppException(
            status_code=403, detail="The user doesn't have enough privileges"
        )
    return current_user
