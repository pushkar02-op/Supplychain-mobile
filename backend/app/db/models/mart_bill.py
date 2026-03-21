from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class MartBill(Base, AuditMixin):
    __tablename__ = "invoice"

    id = Column(Integer, primary_key=True, index=True)
    mart_id = Column(Integer, ForeignKey("mart.id"), nullable=False)
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )
    invoice_date = Column(Date, nullable=False)
    file_path = Column(String, nullable=False)
    file_hash = Column(String, nullable=False, unique=True, index=True)
    total_amount = Column(Numeric(18, 6), nullable=True)
    # Lifecycle Status: 'PROCESSING', 'NEEDS_REVIEW', 'VERIFIED'
    status = Column(String, default="PROCESSING", nullable=False)
    locked_at = Column(DateTime, nullable=True)
    locked_by = Column(String, nullable=True)
    locked_by = Column(String, nullable=True)
    remarks = Column(String, nullable=True)
    format_type = Column(String, nullable=True)

    mart = relationship("Mart")
    warehouse = relationship("Warehouse")
    items = relationship(
        "MartBillItem", back_populates="bill", cascade="all, delete-orphan"
    )
