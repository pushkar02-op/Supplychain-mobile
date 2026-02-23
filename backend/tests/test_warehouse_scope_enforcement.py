from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.exceptions import AppException
from app.db.base import Base
from app.db.enums.role import Role
from app.db.models.user import User
from app.db.models.user_warehouse_access import UserWarehouseAccess
from app.db.models.warehouse import Warehouse
from app.services.warehouse_scope import (
    resolve_warehouse_for_request,
    validate_warehouse_access,
)


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    w1 = Warehouse(name="Main Warehouse", code="MAIN", is_active=True)
    w2 = Warehouse(name="Secondary Warehouse", code="SEC", is_active=True)
    session.add_all([w1, w2])
    session.flush()

    owner = User(
        username="owner",
        full_name="Owner",
        hashed_password="x",
        role=Role.OWNER,
        is_active=True,
    )
    manager = User(
        username="manager",
        full_name="Manager",
        hashed_password="x",
        role=Role.MANAGER,
        is_active=True,
    )
    worker = User(
        username="worker",
        full_name="Worker",
        hashed_password="x",
        role=Role.WORKER,
        is_active=True,
    )
    worker_multi = User(
        username="worker_multi",
        full_name="Worker Multi",
        hashed_password="x",
        role=Role.WORKER,
        is_active=True,
    )
    session.add_all([owner, manager, worker, worker_multi])
    session.flush()

    session.add_all(
        [
            UserWarehouseAccess(user_id=manager.id, warehouse_id=w1.id),
            UserWarehouseAccess(user_id=worker.id, warehouse_id=w1.id),
            UserWarehouseAccess(user_id=worker_multi.id, warehouse_id=w1.id),
            UserWarehouseAccess(user_id=worker_multi.id, warehouse_id=w2.id),
        ]
    )
    session.commit()

    yield (
        session,
        {
            "w1": w1.id,
            "w2": w2.id,
            "owner": owner.id,
            "manager": manager.id,
            "worker": worker.id,
            "worker_multi": worker_multi.id,
        },
    )

    session.close()


def _user(user_id: int, role: Role):
    return SimpleNamespace(id=user_id, role=role, is_active=True)


def test_owner_missing_warehouse_id_rejected_400(db_session):
    db, ids = db_session
    with pytest.raises(AppException) as exc:
        resolve_warehouse_for_request(_user(ids["owner"], Role.OWNER), None, db, "read")
    assert exc.value.status_code == 400


def test_manager_missing_warehouse_id_rejected_400(db_session):
    db, ids = db_session
    with pytest.raises(AppException) as exc:
        resolve_warehouse_for_request(
            _user(ids["manager"], Role.MANAGER), None, db, "read"
        )
    assert exc.value.status_code == 400


def test_worker_single_assignment_auto_infers_warehouse(db_session):
    db, ids = db_session
    resolved = resolve_warehouse_for_request(
        _user(ids["worker"], Role.WORKER), None, db, "read"
    )
    assert resolved == ids["w1"]


def test_worker_multi_assignment_missing_warehouse_rejected_400(db_session):
    db, ids = db_session
    with pytest.raises(AppException) as exc:
        resolve_warehouse_for_request(
            _user(ids["worker_multi"], Role.WORKER), None, db, "read"
        )
    assert exc.value.status_code == 400


def test_manager_unassigned_warehouse_rejected_403_aut004(db_session):
    db, ids = db_session
    with pytest.raises(AppException) as exc:
        resolve_warehouse_for_request(
            _user(ids["manager"], Role.MANAGER), ids["w2"], db, "update"
        )
    assert exc.value.status_code == 403
    assert exc.value.rule_id == "AUT-004"


def test_cross_warehouse_mutation_rejected_403_aut004(db_session):
    db, ids = db_session
    with pytest.raises(AppException) as exc:
        validate_warehouse_access(_user(ids["worker"], Role.WORKER), ids["w2"], db)
    assert exc.value.status_code == 403
    assert exc.value.rule_id == "AUT-004"
