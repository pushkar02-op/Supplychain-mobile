from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin


class Company(Base, AuditMixin):
    __tablename__ = "company"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

    users = relationship("User", back_populates="company")
    marts = relationship("Mart", back_populates="company")
