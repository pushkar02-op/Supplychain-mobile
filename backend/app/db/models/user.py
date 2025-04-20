from sqlalchemy import Column, Integer, String, Boolean
from .base_class import Base
from .mixins import AuditMixin

class User(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_admin = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
