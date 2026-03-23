"""
Structured JSON logging configuration with request ID injection.
"""

import json
import logging
import logging.config
import os
from datetime import datetime, timezone

from app.core.correlation import get_correlation_id


class JSONFormatter(logging.Formatter):
    """Emit each log record as a single-line JSON object."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": getattr(record, "request_id", None),
            "correlation_id": getattr(record, "correlation_id", None),
        }
        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)
        # Merge any extra fields passed via logger.info("msg", extra={...})
        _skip = {
            "name",
            "msg",
            "args",
            "created",
            "filename",
            "funcName",
            "levelname",
            "levelno",
            "lineno",
            "module",
            "msecs",
            "pathname",
            "process",
            "processName",
            "relativeCreated",
            "stack_info",
            "thread",
            "threadName",
            "exc_info",
            "exc_text",
            "message",
            "request_id",
            "correlation_id",
            "taskName",
        }
        for key, value in record.__dict__.items():
            if key not in _skip and not key.startswith("_"):
                log_entry[key] = value
        return json.dumps(log_entry, default=str)


class RequestIdFilter(logging.Filter):
    """Inject the current correlation/request ID into every log record."""

    def filter(self, record: logging.LogRecord) -> bool:
        cid = get_correlation_id()
        record.request_id = cid
        record.correlation_id = cid
        return True


def setup_logging() -> None:
    """Configure structured JSON logging with request ID injection."""
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()

    log_dir = os.getenv("LOG_DIR", "logs")
    os.makedirs(log_dir, exist_ok=True)

    config = {
        "version": 1,
        "disable_existing_loggers": False,
        "filters": {
            "request_id": {
                "()": RequestIdFilter,
            },
        },
        "formatters": {
            "json": {
                "()": JSONFormatter,
            },
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "formatter": "json",
                "filters": ["request_id"],
            },
            "file": {
                "class": "logging.handlers.RotatingFileHandler",
                "filename": os.path.join(log_dir, "app.log"),
                "maxBytes": 10 * 1024 * 1024,  # 10 MB
                "backupCount": 5,
                "formatter": "json",
                "filters": ["request_id"],
            },
        },
        "root": {
            "level": log_level,
            "handlers": ["console", "file"],
        },
    }

    logging.config.dictConfig(config)
