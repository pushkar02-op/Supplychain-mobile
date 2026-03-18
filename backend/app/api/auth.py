"""
API endpoints for authentication.
Handles user registration and login.
"""

import logging
from datetime import datetime, timezone

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.core.rate_limit import limiter
from app.db.enums.role import Role
from app.db.models.auth import RefreshToken
from app.db.models.user import User
from app.db.schemas.auth import Token, TokenRefresh, UserCreate, UserLogin
from app.db.session import get_db
from app.services.auth import login_user, refresh_token, register_user
from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/register", response_model=Token)
def register(
    user: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> Token:
    """
    Register a new user.

    Args:
        user (UserCreate): User registration data.
        db (Session): Database session dependency.

    Returns:
        Token: JWT token for the new user.
    """
    logger.info("Registering new user")
    return register_user(db, user, created_by=current_user.username)


@router.post("/login", response_model=Token)
@limiter.limit("5/minute")
def login(request: Request, user: UserLogin, db: Session = Depends(get_db)) -> Token:
    """
    Authenticate an existing user.

    Args:
        user (UserLogin): User login credentials.
        db (Session): Database session dependency.

    Returns:
        Token: JWT token for the authenticated user.
    """
    logger.info("User login attempt")
    return login_user(db, user)


@router.post("/refresh", response_model=Token)
@limiter.limit("10/minute")
def refresh(
    request: Request, token_data: TokenRefresh, db: Session = Depends(get_db)
) -> Token:
    """
    Refresh access token using a refresh token.
    Revokes the old refresh token and issues a new pair.
    """
    logger.info("Token refresh attempt")
    return refresh_token(db, token_data.refresh_token)


@router.post("/logout")
def logout(db: Session = Depends(get_db), authorization: str = Header(None)):
    """
    Logout user by revoking current refresh token.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise AppException("Invalid authorization header", status_code=400)

    token = authorization.split(" ")[1]
    db_token = (
        db.query(RefreshToken)
        .filter(RefreshToken.token == token, RefreshToken.revoked_at.is_(None))
        .first()
    )
    if db_token:
        db_token.revoked_at = datetime.now(timezone.utc)
        db.commit()

    return {"message": "Logged out successfully"}
