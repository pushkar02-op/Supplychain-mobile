"""
Audit utilities.
Helpers to normalize user identity for dual-write audit logging.
"""

import logging
from typing import TYPE_CHECKING, Optional, Tuple, Union

from sqlalchemy.orm import Session

if TYPE_CHECKING:
    from app.db.models.user import User

logger = logging.getLogger(__name__)


def resolve_user_audit(
    db: Session, user_identity: Union[str, int, "User", None]
) -> Tuple[Optional[str], Optional[int]]:
    """
    Resolve a user identity into (username, user_id).

    Args:
        db: Database session.
        user_identity: user_id (int), username (str), User object, or None.

    Returns:
        Tuple[str, Optional[int]]: (created_by_username, created_by_id)

    Note:
        - If user_identity is None, returns (None, None).
        - If user is not found, returns (username_input, None).
        - created_by (str) is a SNAPSHOT.
        - created_by_id (int) is a REFERENCE.
    """
    if user_identity is None:
        return None, None

    from app.db.models.user import User

    # Case 1: User Object
    if hasattr(user_identity, "username") and hasattr(user_identity, "id"):
        return user_identity.username, user_identity.id

    # Case 2: Integer ID
    if isinstance(user_identity, int):
        user = db.query(User).filter(User.id == user_identity).first()
        if user:
            return user.username, user.id
        else:
            logger.warning(f"Audit: User ID {user_identity} not found.")
            # Fallback: We don't have a username, so we return stringified ID?
            # Prompt says: "No service may write raw IDs into created_by (String)"
            # But if we don't find the user, we can't get the username.
            # We must return SOMETHING for created_by (Snapshot).
            return str(user_identity), None

    # Case 3: String Username
    if isinstance(user_identity, str):
        # Check if it looks like an int (legacy data issue)
        if user_identity.isdigit():
            user_id = int(user_identity)
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                return user.username, user.id
            else:
                return user_identity, None  # Deleted user ID or just a number string

        # Normal Username
        user = db.query(User).filter(User.username == user_identity).first()
        if user:
            return user.username, user.id
        else:
            # User might be deleted or simple string entry
            return user_identity, None

    return str(user_identity), None
