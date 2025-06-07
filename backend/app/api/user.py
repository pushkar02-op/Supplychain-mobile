"""
API endpoints for user management.
Provides retrieval, update, and deletion of users.
"""

import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

from app.core.exceptions import AppException
from app.db.schemas.user import UserRead, UserUpdate
from app.services.user import (
    get_user,
    get_all_users,
    update_user,
    delete_user,
)
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/", response_model=List[UserRead], summary="List users")
def read_users(
    skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
) -> List[UserRead]:
    """
    Retrieve all users with pagination.

    Args:
        skip (int): Number of records to skip.
        limit (int): Maximum number of records to return.
        db (Session): Database session dependency.

    Returns:
        List[UserRead]: List of users.
    """
    logger.info(f"Fetching users skip={skip}, limit={limit}")
    return get_all_users(db=db, skip=skip, limit=limit)


@router.get("/{user_id}", response_model=UserRead, summary="Get user by ID")
def read_user(user_id: int, db: Session = Depends(get_db)) -> UserRead:
    """
    Retrieve a single user by ID.

    Args:
        user_id (int): User ID.
        db (Session): Database session dependency.

    Returns:
        UserRead: The user.

    Raises:
        AppException: If user not found (404).
    """
    logger.info(f"Fetching user id={user_id}")
    user = get_user(db, user_id)
    if not user:
        logger.error(f"User not found: id={user_id}")
        raise AppException("User not found", status_code=404)
    return user


@router.put("/{user_id}", response_model=UserRead, summary="Update user")
def update_user_route(
    user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)
) -> UserRead:
    """
    Update an existing user by ID.

    Args:
        user_id (int): User ID.
        user_update (UserUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        UserRead: The updated user.

    Raises:
        AppException: If user not found (404).
    """
    logger.info(f"Updating user id={user_id}")
    updated = update_user(
        db=db, user_id=user_id, user_update=user_update, updated_by="system"
    )
    if not updated:
        logger.error(f"User not found: id={user_id}")
        raise AppException("User not found", status_code=404)
    return updated


@router.delete(
    "/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete user"
)
def delete_user_route(user_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a user by ID.

    Args:
        user_id (int): User ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If user not found (404).
    """
    logger.info(f"Deleting user id={user_id}")
    success = delete_user(db=db, user_id=user_id)
    if not success:
        logger.error(f"User not found: id={user_id}")
        raise AppException("User not found", status_code=404)
    return None
