"""
API endpoints for user management.
Provides retrieval, update, role management, warehouse assignment controls,
and self-profile access.
"""

import logging
from typing import List

from app.core.auth import get_current_user, require_role
from app.core.exceptions import AppException
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.models.warehouse import Warehouse
from app.db.schemas.user import (
    ChangePasswordRequest,
    StatusResponse,
    UpdateProfileRequest,
    UserCreateGoverned,
    UserProfileRead,
    UserRead,
    UserRoleUpdate,
    UserUpdate,
    UserWarehouseAccessRead,
)
from app.db.session import get_db
from app.services.user import (
    assign_warehouse_to_user,
    change_password,
    create_user_governed,
    delete_user,
    get_all_users,
    get_user,
    get_user_profile_with_warehouses,
    list_user_warehouses,
    remove_warehouse_from_user,
    update_user,
    update_user_profile,
    update_user_role,
)
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserProfileRead, summary="Get current user profile")
def read_current_user(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserProfileRead:
    logger.info(f"Fetching current user profile id={current_user.id}")
    return get_user_profile_with_warehouses(db=db, user_id=current_user.id)


@router.patch(
    "/me", response_model=UserProfileRead, summary="Update current user profile"
)
def update_current_user_profile(
    profile_update: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> UserProfileRead:
    logger.info(f"Updating current user profile id={current_user.id}")
    update_user_profile(
        db=db,
        user_id=current_user.id,
        full_name=profile_update.full_name,
        updated_by=current_user.username,
    )
    return get_user_profile_with_warehouses(db=db, user_id=current_user.id)


@router.post(
    "/change-password",
    response_model=StatusResponse,
    summary="Change current user password",
)
def change_current_user_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> StatusResponse:
    logger.info(f"Changing password for user id={current_user.id}")
    change_password(
        db=db,
        user_id=current_user.id,
        old_password=payload.old_password,
        new_password=payload.new_password,
        updated_by=current_user.username,
    )
    return StatusResponse(status="password_updated")


@router.get("/", response_model=List[UserRead], summary="List users")
def read_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> List[UserRead]:
    logger.info(f"Fetching users skip={skip}, limit={limit}")
    return get_all_users(db=db, skip=skip, limit=limit)


@router.post("/", response_model=UserRead, summary="Create user")
def create_user_route(
    user_create: UserCreateGoverned,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER, Role.MANAGER)),
) -> UserRead:
    logger.info(f"Creating user {user_create.username}")
    return create_user_governed(db=db, actor_user=current_user, user_create=user_create)


@router.get("/{user_id}", response_model=UserRead, summary="Get user by ID")
def read_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> UserRead:
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
    logger.info(f"Updating user id={user_id}")
    updated = update_user(
        db=db,
        user_id=user_id,
        user_update=user_update,
        updated_by=current_user.username,
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


@router.post(
    "/{user_id}/assign-warehouse",
    response_model=UserWarehouseAccessRead,
    summary="Assign warehouse to user",
)
def assign_warehouse_route(
    user_id: int,
    warehouse_id: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> UserWarehouseAccessRead:
    logger.info(f"Assigning warehouse {warehouse_id} to user {user_id}")
    access = assign_warehouse_to_user(
        db=db,
        user_id=user_id,
        warehouse_id=warehouse_id,
        actor_user_id=current_user.id,
    )
    warehouse = db.get(Warehouse, access.warehouse_id)
    return UserWarehouseAccessRead(
        warehouse_id=access.warehouse_id,
        warehouse_name=warehouse.name if warehouse else "",
        warehouse_code=warehouse.code if warehouse else "",
    )


@router.delete(
    "/{user_id}/remove-warehouse",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove warehouse from user",
)
def remove_warehouse_route(
    user_id: int,
    warehouse_id: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> None:
    logger.info(f"Removing warehouse {warehouse_id} from user {user_id}")
    remove_warehouse_from_user(
        db=db,
        user_id=user_id,
        warehouse_id=warehouse_id,
        actor_user_id=current_user.id,
    )
    return None


@router.get(
    "/{user_id}/warehouses",
    response_model=List[UserWarehouseAccessRead],
    summary="List warehouses assigned to user",
)
def list_user_warehouses_route(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> List[UserWarehouseAccessRead]:
    logger.info(f"Listing warehouses for user {user_id}")
    rows = list_user_warehouses(db=db, user_id=user_id)
    return [UserWarehouseAccessRead(**row) for row in rows]


@router.delete(
    "/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Deactivate user"
)
def delete_user_route(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> None:
    logger.info(f"Deactivating user id={user_id}")
    success = delete_user(db=db, user_id=user_id, deleted_by_user_id=current_user.id)
    if not success:
        logger.error(f"User not found: id={user_id}")
        raise AppException("User not found", status_code=404)
    return None
