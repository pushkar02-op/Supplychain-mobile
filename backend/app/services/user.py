"""
Service functions for user management.
Handles retrieval, update, and deletion of user records.
"""

import logging
from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session

from app.core.exceptions import AppException
from app.db.models.user import User
from app.db.schemas.user import UserUpdate

logger = logging.getLogger(__name__)


def get_user(db: Session, user_id: int) -> Optional[User]:
    """
    Retrieve a user by ID.

    Args:
        db (Session): Database session.
        user_id (int): User ID.

    Returns:
        Optional[User]: User or None.
    """
    logger.debug(f"Retrieving user id={user_id}")
    return db.query(User).filter(User.id == user_id).first()


def get_all_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """
    Retrieve all users with pagination.

    Args:
        db (Session): Database session.
        skip (int): Records to skip.
        limit (int): Max records to return.

    Returns:
        List[User]: List of users.
    """
    logger.debug(f"Fetching users skip={skip}, limit={limit}")
    return db.query(User).offset(skip).limit(limit).all()


def update_user(
    db: Session, user_id: int, user_update: UserUpdate, updated_by: Optional[str] = None
) -> Optional[User]:
    """
    Update a user's profile.

    Args:
        db (Session): Database session.
        user_id (int): User ID.
        user_update (UserUpdate): Fields to update.
        updated_by (Optional[str]): Updater ID.

    Returns:
        Optional[User]: Updated user or None.

    Raises:
        AppException: If user not found.
    """
    logger.info(f"Updating user id={user_id}")
    user = get_user(db, user_id)
    if not user:
        logger.error(f"User not found id={user_id}")
        raise AppException("User not found", status_code=404)

    for key, val in user_update.dict(exclude_unset=True).items():
        setattr(user, key, val)
    user.updated_by = updated_by
    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    logger.debug(f"User id={user_id} updated")
    return user


def delete_user(db: Session, user_id: int) -> bool:
    """
    Delete a user by ID.

    Args:
        db (Session): Database session.
        user_id (int): User ID.

    Returns:
        bool: True if deleted, False otherwise.
    """
    logger.info(f"Deleting user id={user_id}")
    user = get_user(db, user_id)
    if not user:
        logger.error(f"User not found id={user_id}")
        return False
    db.delete(user)
    db.commit()
    logger.debug(f"User id={user_id} deleted")
    return True
