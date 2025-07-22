from sqlalchemy import Column, Integer, String, Date, Boolean, Float, ForeignKey
from .base_class import Base
from .mixins import AuditMixin
from sqlalchemy.orm import relationship


class Invoice(Base, AuditMixin):
    __tablename__ = "invoice"

    id = Column(Integer, primary_key=True, index=True)
    mart_id = Column(Integer, ForeignKey("mart.id"), nullable=False)
    invoice_date = Column(Date, nullable=False)
    file_path = Column(String, nullable=False)
    file_hash = Column(String, nullable=False, unique=True, index=True)
    total_amount = Column(Float, nullable=True)
    is_verified = Column(Boolean, default=False)
    remarks = Column(String, nullable=True)

    mart = relationship("Mart")
    items = relationship(
        "InvoiceItem", back_populates="invoice", cascade="all, delete-orphan"
    )
