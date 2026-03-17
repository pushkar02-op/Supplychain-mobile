import logging
import secrets
import string
from datetime import datetime, timedelta, timezone

from app.core.config import settings
from app.core.exceptions import AppException
from app.core.security import create_access_token, hash_password, verify_password
from app.db.models.auth import RefreshToken
from app.db.models.user import User
from app.db.schemas.auth import Token, UserCreate, UserLogin
from fastapi import status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def register_user(db: Session, user: UserCreate) -> Token:
    """
    Register a new user and return a JWT.

    Args:
        db (Session): Database session.
        user (UserCreate): Data for new user.

    Returns:
        Token: JWT access token.

    Raises:
        AppException: If username already exists or on DB error.
    """
    logger.info(f"Registering user '{user.username}'")
    existing = db.query(User).filter(User.username == user.username).first()
    if existing:
        logger.error(f"Username already registered: {user.username}")
        raise AppException(
            "Username already registered", status_code=status.HTTP_400_BAD_REQUEST
        )

    hashed = hash_password(user.password)
    new_user = User(
        username=user.username,
        full_name=user.full_name,
        hashed_password=hashed,
        created_by=user.username,
        updated_by=user.username,
    )
    try:
        db.add(new_user)
        db.flush()
        refresh_token = create_refresh_token(db, new_user.id, commit=False)
        db.commit()
        db.refresh(new_user)
    except Exception:
        db.rollback()
        logger.exception("Failed to create user")
        raise AppException("User registration failed", status_code=500)

    access_token = create_access_token(
        data={
            "sub": new_user.username,
            "uid": new_user.id,
            "role": new_user.role.value,
        }
    )

    logger.info(f"User '{user.username}' registered successfully")
    return Token(
        access_token=access_token,
        token_type="bearer",
        role=new_user.role,
        is_admin=new_user.is_admin,
        refresh_token=refresh_token,
        user_id=new_user.id,
    )


def login_user(db: Session, user: UserLogin) -> Token:
    """
    Authenticate a user and return a JWT + Refresh Token.

    Args:
        db (Session): Database session.
        user (UserLogin): Login credentials.

    Returns:
        Token: JWT access token & Refresh Token.

    Raises:
        AppException: If credentials are invalid.
    """
    logger.info(f"Login attempt for user '{user.username}'")
    db_user = db.query(User).filter(User.username == user.username).first()
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        logger.error(f"Invalid credentials for user '{user.username}'")
        raise AppException(
            "Invalid credentials", status_code=status.HTTP_401_UNAUTHORIZED
        )
    if not db_user.is_active:
        raise AppException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user",
            rule_id="AUT-005",
        )

    access_token = create_access_token(
        data={
            "sub": db_user.username,
            "uid": db_user.id,
            "role": db_user.role.value,
        }
    )
    now = datetime.now(timezone.utc)
    try:
        db.query(RefreshToken).filter(
            RefreshToken.user_id == db_user.id,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        ).update({"revoked_at": now}, synchronize_session=False)
        refresh_token = create_refresh_token(db, db_user.id, commit=False)
        db.commit()
    except Exception:
        db.rollback()
        raise

    logger.info(f"User '{user.username}' authenticated successfully")
    return Token(
        access_token=access_token,
        token_type="bearer",
        role=db_user.role,
        is_admin=db_user.is_admin,
        refresh_token=refresh_token,
        user_id=db_user.id,
    )


def create_refresh_token(db: Session, user_id: int, commit: bool = True) -> str:
    """Generates a secure random refresh token and saves to DB."""
    token_str = "".join(
        secrets.choice(string.ascii_letters + string.digits) for _ in range(64)
    )
    refresh_token = RefreshToken(
        token=token_str,
        user_id=user_id,
        expires_at=datetime.utcnow()
        + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(refresh_token)
    if commit:
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise
    else:
        db.flush()
    return token_str


def refresh_token(db: Session, token_str: str) -> Token:
    """
    Rotates refresh token and issues new access token.
    Revokes the used refresh token.
    """
    db_token = db.query(RefreshToken).filter(RefreshToken.token == token_str).first()

    # 1. Existence check
    if not db_token:
        raise AppException(
            "Invalid refresh token", status_code=status.HTTP_401_UNAUTHORIZED
        )

    # 2. Revocation check (Reuse detection)
    if db_token.revoked_at:
        logger.warning(f"Attempted reuse of revoked token: {token_str}")
        # Security: In a stricter system, we might revoke ALL tokens for this user here.
        raise AppException(
            "Invalid refresh token", status_code=status.HTTP_401_UNAUTHORIZED
        )

    # 3. Expiry check
    if db_token.expires_at < datetime.utcnow():
        raise AppException(
            "Refresh token expired", status_code=status.HTTP_401_UNAUTHORIZED
        )

    try:
        # 4. Rotation: Revoke old, issue new
        db_token.revoked_at = datetime.utcnow()

        user = db_token.user
        if not user.is_active:
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Inactive user",
                rule_id="AUT-005",
            )
        new_access_token = create_access_token(
            data={
                "sub": user.username,
                "uid": user.id,
                "role": user.role.value,
            }
        )
        new_refresh_token = create_refresh_token(db, user.id, commit=False)
        db.commit()
    except Exception:
        db.rollback()
        raise

    return Token(
        access_token=new_access_token,
        token_type="bearer",
        role=user.role,
        is_admin=user.is_admin,
        refresh_token=new_refresh_token,
        user_id=db_token.user_id,
    )


def prune_expired_tokens(db: Session) -> None:
    now = datetime.now(timezone.utc)
    db.query(RefreshToken).filter(
        (RefreshToken.expires_at < now) | (RefreshToken.revoked_at.is_not(None))
    ).delete(synchronize_session=False)
    db.commit()
