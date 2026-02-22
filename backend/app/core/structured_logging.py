import json
import logging
from datetime import datetime, timezone
from typing import Optional

from app.core.correlation import get_correlation_id


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "event": getattr(record, "event", record.getMessage()),
            "rule_id": getattr(record, "rule_id", None),
            "correlation_id": getattr(record, "correlation_id", get_correlation_id()),
            "metadata": getattr(record, "metadata", {}),
        }
        return json.dumps(payload, default=str)


def _level_name_to_int(level: str) -> int:
    return getattr(logging, level.upper(), logging.INFO)


def log_event(
    level: str,
    event: str,
    rule_id: Optional[str] = None,
    metadata: Optional[dict] = None,
) -> None:
    payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "correlation_id": get_correlation_id(),
        "rule_id": rule_id,
        "event": event,
        "metadata": metadata or {},
    }
    logger = logging.getLogger("app.structured")
    logger.log(_level_name_to_int(level), json.dumps(payload, default=str))
