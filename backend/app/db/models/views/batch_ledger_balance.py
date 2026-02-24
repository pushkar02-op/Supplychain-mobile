from app.db.models.base_class import Base
from sqlalchemy import Column, Integer, Numeric


class BatchLedgerBalance(Base):
    __tablename__ = "batch_ledger_balance_view"
    __table_args__ = {"info": {"is_view": True}}

    warehouse_id = Column(Integer, primary_key=True)
    batch_id = Column(Integer, primary_key=True)
    ledger_qty = Column(Numeric(10, 3))

    def __repr__(self):
        return f"<BatchLedgerBalance(batch_id={self.batch_id}, ledger_qty={self.ledger_qty})>"
