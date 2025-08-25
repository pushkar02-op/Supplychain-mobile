"""
API endpoints for authentication.
Handles user registration and login.
"""

import logging

from app.db.schemas.auth import Token, UserCreate, UserLogin
from app.db.session import get_db
from app.services.auth import login_user, register_user
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/register", response_model=Token)
def register(user: UserCreate, db: Session = Depends(get_db)) -> Token:
    """
    Register a new user.

    Args:
        user (UserCreate): User registration data.
        db (Session): Database session dependency.

    Returns:
        Token: JWT token for the new user.
    """
    logger.info("Registering new user")
    return register_user(db, user)


@router.post("/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)) -> Token:
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
