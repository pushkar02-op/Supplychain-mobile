from datetime import datetime

from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint

from .base_class import Base


class IdempotencyRecord(Base):
    __tablename__ = "idempotency_record"
    __table_args__ = (
        UniqueConstraint(
            "idempotency_key", "endpoint", name="uq_idempotency_key_endpoint"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    idempotency_key = Column(String, nullable=False, index=True)
    endpoint = Column(String, nullable=False)
    request_hash = Column(String, nullable=False)

    # Store reference to the created entity to reconstruct response
    result_entity_type = Column(
        String, nullable=False
    )  # e.g. "stock_entry", "rejection_entry"
    result_entity_id = Column(String, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
