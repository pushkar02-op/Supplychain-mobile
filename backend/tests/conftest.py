import os

import pytest
from fastapi.testclient import TestClient

# Ensure tests run without docker dependencies.
os.environ["RUN_MIGRATIONS_ON_STARTUP"] = "false"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["SEED_INITIAL_DATA"] = "false"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-that-is-at-least-32-chars-long"

from app.main import app
from app.db.enums.role import Role
from app.db.base import Base
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.user import User
from app.db.models.user_warehouse_access import UserWarehouseAccess
from app.db.models.uom import UOM
from app.db.models.warehouse import Warehouse
from app.db.session import get_db
from sqlalchemy import create_engine, insert, select
from sqlalchemy import event
from sqlalchemy.orm import Session as SASession, sessionmaker

# Use in-memory SQLite for speed and isolation
from sqlalchemy.pool import StaticPool

# Use in-memory SQLite for speed and isolation
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _ensure_main_warehouse(session: SASession) -> int:
    conn = session.connection()
    table = Warehouse.__table__
    main_id = conn.execute(
        select(table.c.id).where(table.c.code == "MAIN")
    ).scalar_one_or_none()
    if main_id is None:
        conn.execute(
            insert(table).values(name="Main Warehouse", code="MAIN", is_active=True)
        )
        main_id = conn.execute(
            select(table.c.id).where(table.c.code == "MAIN")
        ).scalar_one()
    return int(main_id)


@event.listens_for(SASession, "before_flush")
def _inject_default_warehouse(session, _flush_context, _instances):
    main_warehouse_id = None
    for obj in list(session.new):
        if hasattr(obj, "warehouse_id") and getattr(obj, "warehouse_id", None) is None:
            if main_warehouse_id is None:
                main_warehouse_id = _ensure_main_warehouse(session)
            setattr(obj, "warehouse_id", main_warehouse_id)


@pytest.fixture(scope="function")
def db_session():
    # Create tables
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        main_warehouse_id = _ensure_main_warehouse(session)
        users = session.query(User).all()
        for user in users:
            exists = (
                session.query(UserWarehouseAccess)
                .filter(
                    UserWarehouseAccess.user_id == user.id,
                    UserWarehouseAccess.warehouse_id == main_warehouse_id,
                )
                .first()
            )
            if not exists:
                session.add(
                    UserWarehouseAccess(
                        user_id=user.id,
                        warehouse_id=main_warehouse_id,
                    )
                )
        session.flush()
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    # Override get_db dependency to use the test session
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    # Override get_current_user
    from app.core.auth import get_current_user
    from types import SimpleNamespace

    mock_user = SimpleNamespace(
        id=1,
        username="tester",
        full_name="Test User",
        role=Role.OWNER,
        is_active=True,
        is_admin=True,
    )

    def override_get_current_user():
        return mock_user

    app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def create_mart(db_session):
    def _create_mart(name="TestMart"):
        mart = Mart(name=name, company_name="TestCompany")
        db_session.add(mart)
        db_session.commit()
        db_session.refresh(mart)
        return mart

    return _create_mart


@pytest.fixture(scope="function")
def create_item(db_session):
    def _create_item(name="TestItem"):
        # Ensure default UOM exists
        uom = db_session.query(UOM).filter_by(code="kg").first()
        if not uom:
            uom = UOM(code="kg", description="Kilogram")
            db_session.add(uom)
            db_session.commit()

        # uom.id is the primary key (Integer), uom.code is String
        item = Item(name=name, default_uom_id=uom.id)
        db_session.add(item)
        db_session.commit()
        db_session.refresh(item)
        return item

    return _create_item
