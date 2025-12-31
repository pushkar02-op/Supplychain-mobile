from datetime import datetime
from sqlalchemy import Column, Integer, String, ForeignKey, UniqueConstraint, DateTime
from sqlalchemy.orm import relationship
from app.db.models.base_class import Base

class MartItemAlias(Base):
    __tablename__ = "mart_item_alias"

    id = Column(Integer, primary_key=True, index=True)
    mart_id = Column(Integer, ForeignKey("mart.id"), nullable=False)
    item_id = Column(Integer, ForeignKey("item.id"), nullable=False)
    alias_code = Column(String, nullable=True)
    alias_name = Column(String, nullable=False)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_by = Column(String, nullable=True)

    # Relationships
    mart = relationship("Mart")
    item = relationship("Item")

    __table_args__ = (
        UniqueConstraint('mart_id', 'alias_code', name='uq_mart_alias_code'),
        UniqueConstraint('mart_id', 'alias_name', name='uq_mart_alias_name'),
    )
