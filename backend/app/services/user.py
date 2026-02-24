"""
Service functions for user management.
Handles retrieval, update, and deletion of user records.
"""

import logging
from datetime import datetime
from typing import List, Optional

from app.core.exceptions import AppException
from app.core.security import hash_password
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.models.user_warehouse_access import UserWarehouseAccess
from app.db.models.warehouse import Warehouse
from app.db.schemas.user import UserCreateGoverned, UserUpdate
from app.services.audit import log_action
from sqlalchemy.orm import Session

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


def _owner_count(db: Session) -> int:
    return db.query(User).filter(User.role == Role.OWNER).count()


def _assert_can_create_role(actor_role: Role, new_role: Role) -> None:
    if actor_role == Role.OWNER and new_role in {Role.MANAGER, Role.WORKER}:
        return
    if actor_role == Role.MANAGER and new_role == Role.WORKER:
        return
    raise AppException(
        "Insufficient permissions",
        status_code=403,
        rule_id="AUT-001",
        metadata={},
    )


def create_user_governed(
    db: Session,
    actor_user: User,
    user_create: UserCreateGoverned,
) -> User:
    _assert_can_create_role(actor_user.role, user_create.role)

    existing = db.query(User).filter(User.username == user_create.username).first()
    if existing:
        raise AppException("Username already registered", status_code=400)

    try:
        user = User(
            username=user_create.username,
            full_name=user_create.full_name,
            hashed_password=hash_password(user_create.password),
            role=user_create.role,
            is_active=True,
            created_by=actor_user.username,
            updated_by=actor_user.username,
        )
        db.add(user)
        db.flush()
        log_action(
            db=db,
            actor_user_id=actor_user.id,
            action_type="user_created",
            entity_type="user",
            entity_id=user.id,
            metadata={"role": user.role.value, "username": user.username},
        )
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise
    return user


def update_user_role(
    db: Session,
    user_id: int,
    new_role: Role,
    actor_user_id: int,
    updated_by: Optional[str] = None,
) -> Optional[User]:
    logger.info(f"Updating role for user id={user_id} to {new_role.value}")
    user = get_user(db, user_id)
    if not user:
        logger.error(f"User not found id={user_id}")
        raise AppException("User not found", status_code=404)

    if actor_user_id == user_id:
        raise AppException(
            "Users cannot change their own role",
            status_code=400,
            rule_id="AUT-002",
            metadata={},
        )

    if user.role == Role.OWNER and new_role != Role.OWNER and _owner_count(db) <= 1:
        raise AppException(
            "At least one OWNER must remain in system",
            status_code=400,
            rule_id="AUT-003",
            metadata={},
        )

    try:
        user.role = new_role
        user.updated_by = updated_by
        user.updated_at = datetime.utcnow()
        log_action(
            db=db,
            actor_user_id=actor_user_id,
            action_type="user_role_changed",
            entity_type="user",
            entity_id=user.id,
            metadata={"new_role": new_role.value},
        )
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise
    logger.debug(f"User id={user_id} role updated")
    return user


def assign_warehouse_to_user(
    db: Session,
    user_id: int,
    warehouse_id: int,
    actor_user_id: int,
) -> UserWarehouseAccess:
    user = get_user(db, user_id)
    if not user:
        raise AppException("User not found", status_code=404)
    if user.role == Role.OWNER:
        raise AppException(
            "OWNER has implicit warehouse access",
            status_code=400,
            metadata={},
        )

    warehouse = db.get(Warehouse, warehouse_id)
    if not warehouse:
        raise AppException("Warehouse not found", status_code=404)

    existing = (
        db.query(UserWarehouseAccess)
        .filter(
            UserWarehouseAccess.user_id == user_id,
            UserWarehouseAccess.warehouse_id == warehouse_id,
        )
        .first()
    )
    if existing:
        raise AppException("Warehouse already assigned to user", status_code=409)

    try:
        access = UserWarehouseAccess(user_id=user_id, warehouse_id=warehouse_id)
        db.add(access)
        db.flush()
        log_action(
            db=db,
            actor_user_id=actor_user_id,
            action_type="warehouse_assigned",
            entity_type="user_warehouse_access",
            entity_id=access.id,
            metadata={"user_id": user_id, "warehouse_id": warehouse_id},
        )
        db.commit()
        db.refresh(access)
    except Exception:
        db.rollback()
        raise
    return access


def remove_warehouse_from_user(
    db: Session,
    user_id: int,
    warehouse_id: int,
    actor_user_id: int,
) -> None:
    user = get_user(db, user_id)
    if not user:
        raise AppException("User not found", status_code=404)
    if user.role == Role.OWNER:
        raise AppException(
            "OWNER has implicit warehouse access",
            status_code=400,
            metadata={},
        )

    access = (
        db.query(UserWarehouseAccess)
        .filter(
            UserWarehouseAccess.user_id == user_id,
            UserWarehouseAccess.warehouse_id == warehouse_id,
        )
        .first()
    )
    if not access:
        raise AppException("Warehouse assignment not found", status_code=404)

    assignment_count = (
        db.query(UserWarehouseAccess)
        .filter(UserWarehouseAccess.user_id == user_id)
        .count()
    )
    if user.is_active and assignment_count <= 1:
        raise AppException(
            "Cannot remove last warehouse from an active user",
            status_code=400,
            metadata={},
        )

    try:
        log_action(
            db=db,
            actor_user_id=actor_user_id,
            action_type="warehouse_removed",
            entity_type="user_warehouse_access",
            entity_id=access.id,
            metadata={"user_id": user_id, "warehouse_id": warehouse_id},
        )
        db.delete(access)
        db.commit()
    except Exception:
        db.rollback()
        raise


def list_user_warehouses(
    db: Session,
    user_id: int,
) -> List[dict]:
    user = get_user(db, user_id)
    if not user:
        raise AppException("User not found", status_code=404)
    if user.role == Role.OWNER:
        return []

    rows = (
        db.query(UserWarehouseAccess, Warehouse)
        .join(Warehouse, Warehouse.id == UserWarehouseAccess.warehouse_id)
        .filter(UserWarehouseAccess.user_id == user_id)
        .all()
    )
    return [
        {
            "warehouse_id": access.warehouse_id,
            "warehouse_name": warehouse.name,
            "warehouse_code": warehouse.code,
        }
        for access, warehouse in rows
    ]


def delete_user(
    db: Session,
    user_id: int,
    deleted_by_user_id: Optional[int] = None,
) -> bool:
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
    if user.role == Role.OWNER and _owner_count(db) <= 1:
        raise AppException(
            "At least one OWNER must remain in system",
            status_code=400,
            rule_id="AUT-003",
            metadata={},
        )
    if deleted_by_user_id is not None and deleted_by_user_id == user_id:
        raise AppException(
            "Users cannot delete themselves",
            status_code=400,
            rule_id="AUT-004",
            metadata={},
        )
    try:
        user.is_active = False
        user.updated_at = datetime.utcnow()
        if deleted_by_user_id is not None:
            log_action(
                db=db,
                actor_user_id=deleted_by_user_id,
                action_type="user_deactivated",
                entity_type="user",
                entity_id=user.id,
                metadata={"username": user.username},
            )
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise
    logger.debug(f"User id={user_id} deactivated")
    return True
