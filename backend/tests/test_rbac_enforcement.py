import ast
from pathlib import Path
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.session import get_db
from app.main import app


def _override_db(db_session):
    def _get_db():
        try:
            yield db_session
        finally:
            pass

    return _get_db


def _override_user(role: Role, user_id: int = 1, username: str = "tester"):
    return lambda: SimpleNamespace(
        id=user_id,
        username=username,
        full_name=username,
        role=role,
        is_active=True,
        is_admin=(role == Role.OWNER),
    )


def _create_user(db_session, username: str, role: Role) -> User:
    user = User(
        username=username,
        full_name=username,
        hashed_password="hashed",
        role=role,
        is_active=True,
        created_by="test",
        updated_by="test",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def test_worker_cannot_access_admin_users_and_financial_reports(db_session):
    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(Role.WORKER, user_id=10)

    try:
        with TestClient(app) as client:
            admin_response = client.get("/v1/admin/ledger/health")
            users_response = client.get("/v1/users/")
            pnl_response = client.get("/v1/reports/pnl")
    finally:
        app.dependency_overrides.clear()

    assert admin_response.status_code == 403
    assert users_response.status_code == 403
    assert pnl_response.status_code == 403


def test_manager_cannot_create_users_or_change_roles(db_session):
    target = _create_user(db_session, username="target_worker", role=Role.WORKER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER, user_id=20, username="manager"
    )

    try:
        with TestClient(app) as client:
            register_response = client.post(
                "/v1/register",
                json={
                    "username": "newuser",
                    "full_name": "New User",
                    "password": "secret",
                },
            )
            role_change_response = client.patch(
                f"/v1/users/{target.id}/role", json={"role": "OWNER"}
            )
    finally:
        app.dependency_overrides.clear()

    assert register_response.status_code == 403
    assert register_response.json()["rule_id"] == "AUT-001"
    assert role_change_response.status_code == 403
    assert role_change_response.json()["rule_id"] == "AUT-001"


def test_owner_can_create_users_and_change_roles(db_session, monkeypatch):
    target = _create_user(db_session, username="worker_change", role=Role.WORKER)
    import app.services.auth as auth_service

    monkeypatch.setattr(
        auth_service,
        "create_access_token",
        lambda data, expires_delta=None: "test-token",
    )

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user_id=999, username="owner"
    )

    try:
        with TestClient(app) as client:
            register_response = client.post(
                "/v1/register",
                json={
                    "username": "owner_created_user",
                    "full_name": "Owner Created",
                    "password": "secret",
                },
            )
            role_change_response = client.patch(
                f"/v1/users/{target.id}/role", json={"role": "MANAGER"}
            )
    finally:
        app.dependency_overrides.clear()

    assert register_response.status_code == 200
    register_payload = register_response.json()
    assert register_payload["role"] == "WORKER"
    assert register_payload["is_admin"] is False

    assert role_change_response.status_code == 200
    role_payload = role_change_response.json()
    assert role_payload["role"] == "MANAGER"


def test_register_cannot_create_manager_or_owner(db_session, monkeypatch):
    import app.services.auth as auth_service

    monkeypatch.setattr(
        auth_service,
        "create_access_token",
        lambda data, expires_delta=None: "test-token",
    )

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER, user_id=999, username="owner"
    )

    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/register",
                json={
                    "username": "register_role_attempt",
                    "full_name": "Register Role Attempt",
                    "password": "secret",
                    "role": "MANAGER",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["role"] == "WORKER"
    created_user = (
        db_session.query(User).filter(User.username == "register_role_attempt").first()
    )
    assert created_user is not None
    assert created_user.role == Role.WORKER


def test_role_escalation_controls(db_session):
    worker = _create_user(db_session, username="worker_escalation", role=Role.WORKER)

    app.dependency_overrides[get_db] = _override_db(db_session)

    # Worker cannot promote self (blocked at dependency layer)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.WORKER,
        user_id=worker.id,
        username=worker.username,
    )
    try:
        with TestClient(app) as client:
            worker_response = client.patch(
                f"/v1/users/{worker.id}/role", json={"role": "MANAGER"}
            )
    finally:
        app.dependency_overrides.clear()

    # Manager cannot promote anyone (blocked at dependency layer)
    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.MANAGER, user_id=30, username="manager"
    )
    try:
        with TestClient(app) as client:
            manager_response = client.patch(
                f"/v1/users/{worker.id}/role", json={"role": "OWNER"}
            )
    finally:
        app.dependency_overrides.clear()

    assert worker_response.status_code == 403
    assert worker_response.json()["rule_id"] == "AUT-001"
    assert manager_response.status_code == 403
    assert manager_response.json()["rule_id"] == "AUT-001"


def test_owner_invariants_self_change_and_last_owner_guard(db_session):
    only_owner = _create_user(db_session, username="solo_owner", role=Role.OWNER)

    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER,
        user_id=only_owner.id,
        username=only_owner.username,
    )
    try:
        with TestClient(app) as client:
            self_change_response = client.patch(
                f"/v1/users/{only_owner.id}/role", json={"role": "MANAGER"}
            )
    finally:
        app.dependency_overrides.clear()

    # Use a different acting OWNER identity to hit last-owner invariant
    app.dependency_overrides[get_db] = _override_db(db_session)
    app.dependency_overrides[get_current_user] = _override_user(
        Role.OWNER,
        user_id=999,
        username="acting_owner",
    )
    try:
        with TestClient(app) as client:
            last_owner_response = client.patch(
                f"/v1/users/{only_owner.id}/role", json={"role": "WORKER"}
            )
    finally:
        app.dependency_overrides.clear()

    assert self_change_response.status_code == 400
    assert self_change_response.json()["rule_id"] == "AUT-002"
    assert last_owner_response.status_code == 400
    assert last_owner_response.json()["rule_id"] == "AUT-003"


def test_mutation_routes_require_role_dependency() -> None:
    api_root = Path(__file__).resolve().parents[1] / "app" / "api"
    violations: list[str] = []

    for file in sorted(api_root.glob("*.py")):
        source = file.read_text(encoding="utf-8")
        tree = ast.parse(source)

        for node in tree.body:
            if not isinstance(node, ast.FunctionDef):
                continue

            decorators = [ast.unparse(d) for d in node.decorator_list]
            is_mutation = any(
                f"router.{method}" in deco
                for deco in decorators
                for method in ("post", "put", "patch", "delete")
            )
            if not is_mutation:
                continue

            if file.name == "auth.py" and node.name in {"login", "refresh"}:
                continue

            signature = ast.unparse(node)
            if "Depends(require_role(" not in signature:
                violations.append(f"{file.name}:{node.lineno}:{node.name}")

    assert not violations, "Mutation routes missing role guard:\n" + "\n".join(
        violations
    )
