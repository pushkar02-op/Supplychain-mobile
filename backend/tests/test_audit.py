from unittest.mock import MagicMock

from app.db.models.user import User
from app.utils.audit import resolve_user_audit


def test_resolve_user_audit_with_user_object():
    mock_db = MagicMock()
    user = User(id=1, username="test_user")

    uname, uid = resolve_user_audit(mock_db, user)

    assert uname == "test_user"
    assert uid == 1


def test_resolve_user_audit_with_existing_id():
    mock_db = MagicMock()
    # Mock query return
    mock_db.query.return_value.filter.return_value.first.return_value = User(
        id=2, username="id_user"
    )

    uname, uid = resolve_user_audit(mock_db, 2)

    assert uname == "id_user"
    assert uid == 2


def test_resolve_user_audit_with_missing_id():
    mock_db = MagicMock()
    mock_db.query.return_value.filter.return_value.first.return_value = None

    uname, uid = resolve_user_audit(mock_db, 999)

    # Snapshot behavior for missing ID
    assert uname == "999"
    assert uid is None


def test_resolve_user_audit_with_username_string():
    mock_db = MagicMock()
    mock_db.query.return_value.filter.return_value.first.return_value = User(
        id=3, username="string_user"
    )

    uname, uid = resolve_user_audit(mock_db, "string_user")

    assert uname == "string_user"
    assert uid == 3


def test_resolve_user_audit_with_deleted_username():
    mock_db = MagicMock()
    mock_db.query.return_value.filter.return_value.first.return_value = None

    uname, uid = resolve_user_audit(mock_db, "deleted_user")

    assert uname == "deleted_user"
    assert uid is None
