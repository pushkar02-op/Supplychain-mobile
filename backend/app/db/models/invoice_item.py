from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from .base_class import Base
from .mixins import AuditMixin

class InvoiceItem(Base, AuditMixin):
    __tablename__ = "invoice_item"

    id = Column(Integer, primary_key=True, index=True)
    invoice_id = Column(Integer, ForeignKey("invoice.id"), nullable=False)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=True) 

    # fields from your parser
    hsn_code       = Column(String, nullable=True)
    item_code      = Column(String, nullable=True)
    item_name      = Column(String, nullable=False)
    quantity       = Column(Float, nullable=False)
    uom            = Column(String, nullable=False)
    price          = Column(Float, nullable=False)
    total          = Column(Float, nullable=False)
    invoice_date   = Column(DateTime, nullable=False)
    store_name     = Column(String, nullable=False)

    invoice = relationship("Invoice", back_populates="items")
    item = relationship("Item")
