"""
API endpoints for user management.
Provides retrieval, update, and deletion of users.
"""

import logging
from typing import List

from app.core.auth import require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.schemas.user import UserRead, UserRoleUpdate, UserUpdate
from app.db.session import get_db
from app.services.user import (
    delete_user,
    get_all_users,
    get_user,
    update_user,
    update_user_role,
)
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/", response_model=List[UserRead], summary="List users")
def read_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
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
def read_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> UserRead:
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
    user_id: int,
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
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


@router.patch("/{user_id}/role", response_model=UserRead, summary="Update user role")
def update_user_role_route(
    user_id: int,
    role_update: UserRoleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> UserRead:
    logger.info(f"Updating role for user id={user_id}")
    updated = update_user_role(
        db=db,
        user_id=user_id,
        new_role=role_update.role,
        actor_user_id=current_user.id,
        updated_by=current_user.username,
    )
    if not updated:
        logger.error(f"User not found: id={user_id}")
        raise AppException("User not found", status_code=404)
    return updated


@router.delete(
    "/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete user"
)
def delete_user_route(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> None:
    """
    Delete a user by ID.

    Args:
        user_id (int): User ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If user not found (404).
    """
    logger.info(f"Deleting user id={user_id}")
    success = delete_user(db=db, user_id=user_id, deleted_by_user_id=current_user.id)
    if not success:
        logger.error(f"User not found: id={user_id}")
        raise AppException("User not found", status_code=404)
    return None
