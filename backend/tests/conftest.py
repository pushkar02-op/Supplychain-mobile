import os

import pytest
from fastapi.testclient import TestClient

# Ensure tests run without docker dependencies.
os.environ["RUN_MIGRATIONS_ON_STARTUP"] = "false"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["SEED_INITIAL_DATA"] = "false"

from app.main import app
from app.db.base import Base
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.uom import UOM
from app.db.session import get_db
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

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


@pytest.fixture(scope="function")
def db_session():
    # Create tables
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
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
    from collections import namedtuple

    # Mock User object
    UserMock = namedtuple("UserMock", ["id", "username", "full_name", "is_admin"])
    mock_user = UserMock(id=1, username="tester", full_name="Test User", is_admin=True)

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
