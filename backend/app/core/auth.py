from collections.abc import Callable

from app.core.exceptions import AppException
from app.core.security import verify_access_token
from app.db.enums.role import Role
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

    user = None
    user_id = payload.get("uid")
    if user_id is not None:
        try:
            user = db.get(User, int(user_id))
        except (TypeError, ValueError):
            raise credentials_exception

    if user is None:
        username: str | None = payload.get("sub")
        if username is None:
            raise credentials_exception
        user = db.query(User).filter(User.username == username).first()

    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise AppException(
            status_code=403,
            detail="Inactive user",
            rule_id="AUT-005",
        )
    return user


def require_role(*allowed_roles: Role) -> Callable[[User], User]:
    allowed_role_set = set(allowed_roles)

    def dependency(current_user: User = Depends(get_current_user)) -> User:
        if not current_user.is_active:
            raise AppException(status_code=400, detail="Inactive user")
        if current_user.role not in allowed_role_set:
            raise AppException(
                status_code=403,
                detail="Insufficient permissions",
                rule_id="AUT-001",
                metadata={
                    "allowed_roles": [role.value for role in allowed_roles],
                    "user_role": current_user.role.value,
                },
            )
        return current_user

    return dependency
