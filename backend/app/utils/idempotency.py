import hashlib
import logging
from typing import Any, Optional

from app.core.exceptions import AppException
from app.db.models.idempotency_record import IdempotencyRecord
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def canonical_hash(payload: Any) -> str:
    """
    Produce a stable hash of the given payload (dict).
    Uses string representation for maximum robustness against serialization errors.
    """
    try:
        # Pydantic models/dicts are generally stable in repr/str
        serialized = str(payload)
        return hashlib.sha256(serialized.encode("utf-8")).hexdigest()
    except Exception as e:
        logger.exception("canonical_hash failed")
        raise e


def check_idempotency(
    db: Session, idempotency_key: str, endpoint: str, payload: Any
) -> Optional[IdempotencyRecord]:
    """
    Check if a record exists for this key/endpoint.
    If exists:
      - Validates hash. If mismatch -> Raise 409.
      - Return record.
    If not exists:
      - Return None.
    """
    record = (
        db.query(IdempotencyRecord)
        .filter_by(idempotency_key=idempotency_key, endpoint=endpoint)
        .with_for_update()  # Lock to prevent race on same key
        .first()
    )

    if record:
        input_hash = canonical_hash(payload)
        if record.request_hash != input_hash:
            logger.warning(
                f"Idempotency conflict: key={idempotency_key} used with different payload"
            )
            raise AppException(
                "Idempotency key collision with different payload", status_code=409
            )
        logger.info(f"Idempotency hit: key={idempotency_key}")
        return record

    return None


def save_idempotency_record(
    db: Session,
    idempotency_key: str,
    endpoint: str,
    payload: Any,
    entity_type: str,
    entity_id: str,
) -> IdempotencyRecord:
    """
    Persist the idempotency record. Must be called before commit.
    """
    input_hash = canonical_hash(payload)
    record = IdempotencyRecord(
        idempotency_key=idempotency_key,
        endpoint=endpoint,
        request_hash=input_hash,
        result_entity_type=entity_type,
        result_entity_id=str(entity_id),
    )
    db.add(record)
    db.flush()
    return record
