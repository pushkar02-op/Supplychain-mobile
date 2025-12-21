"""
Service functions for authentication.
Handles user registration and login, issuing JWT tokens.
"""

import logging

from app.core.exceptions import AppException
from app.core.security import create_access_token, hash_password, verify_password
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
        db.commit()
        db.refresh(new_user)
    except Exception:
        logger.exception("Failed to create user")
        raise AppException("User registration failed", status_code=500)

    token = create_access_token(data={"sub": new_user.username})
    logger.info(f"User '{user.username}' registered successfully")
    return Token(access_token=token, token_type="bearer", is_admin=new_user.is_admin)


def login_user(db: Session, user: UserLogin) -> Token:
    """
    Authenticate a user and return a JWT.

    Args:
        db (Session): Database session.
        user (UserLogin): Login credentials.

    Returns:
        Token: JWT access token.

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

    token = create_access_token(data={"sub": db_user.username})
    logger.info(f"User '{user.username}' authenticated successfully")
    return Token(access_token=token, token_type="bearer", is_admin=db_user.is_admin)
