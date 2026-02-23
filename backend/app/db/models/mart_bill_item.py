from sqlalchemy import Column, DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship

from .base_class import Base
from .mixins import AuditMixin


class MartBillItem(Base, AuditMixin):
    __tablename__ = "invoice_item"

    id = Column(Integer, primary_key=True, index=True)
    invoice_id = Column(Integer, ForeignKey("invoice.id"), nullable=False)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=True)
    warehouse_id = Column(
        Integer, ForeignKey("warehouse.id"), nullable=False, index=True
    )

    # fields from your parser
    hsn_code = Column(String, nullable=True)
    item_code = Column(String, nullable=True)
    item_name = Column(String, nullable=False)
    quantity = Column(Numeric(10, 3), nullable=False)
    uom = Column(String, nullable=False)
    price = Column(Numeric(18, 6), nullable=False)
    total = Column(Numeric(18, 6), nullable=False)
    invoice_date = Column(DateTime, nullable=False)
    store_name = Column(String, nullable=False)

    bill = relationship("MartBill", back_populates="items")
    item = relationship("Item")
    warehouse = relationship("Warehouse")
