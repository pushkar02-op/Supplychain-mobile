from sqlalchemy import Column, Integer, String
from .base_class import Base
from .mixins import AuditMixin


class Item(Base, AuditMixin):
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    item_code = Column(String, unique=False, nullable=False)
    default_unit = Column(String, nullable=False)
