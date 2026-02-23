from app.db.enums.role import Role
from sqlalchemy import Boolean, CheckConstraint, Column, Enum, Integer, String

from .base_class import Base
from .mixins import AuditMixin


class User(Base, AuditMixin):
    __tablename__ = "user"
    __table_args__ = (
        CheckConstraint(
            "role IN ('OWNER','MANAGER','WORKER')",
            name="ck_user_role_valid",
        ),
    )
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(
        Enum(Role, name="userrole", native_enum=False, create_constraint=False),
        default=Role.WORKER,
        nullable=False,
    )
    is_active = Column(Boolean, default=True)

    @property
    def is_admin(self) -> bool:
        return self.role == Role.OWNER

    @is_admin.setter
    def is_admin(self, value: bool) -> None:
        self.role = Role.OWNER if value else Role.WORKER
