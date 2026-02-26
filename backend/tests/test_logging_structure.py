"""
Tests for structured JSON logging.
Verifies that log output is valid JSON with required fields.
"""

import json
import logging

from app.core.logging_config import JSONFormatter, RequestIdFilter, setup_logging


def test_json_log_output_structure():
    """Log output must be valid JSON containing timestamp, level, logger, message, request_id."""
    # Re-init logging to ensure JSON formatter is active
    setup_logging()

    formatter = JSONFormatter()
    record = logging.LogRecord(
        name="test.logger",
        level=logging.INFO,
        pathname="test.py",
        lineno=1,
        msg="hello world",
        args=None,
        exc_info=None,
    )
    # Apply request_id filter
    filt = RequestIdFilter()
    filt.filter(record)

    output = formatter.format(record)

    parsed = json.loads(output)

    assert "timestamp" in parsed
    assert parsed["level"] == "INFO"
    assert parsed["logger"] == "test.logger"
    assert parsed["message"] == "hello world"
    assert "request_id" in parsed


def test_json_log_includes_exception():
    """Log output with exc_info must include an 'exception' key."""
    formatter = JSONFormatter()

    try:
        raise ValueError("boom")
    except ValueError:
        import sys

        exc_info = sys.exc_info()

    record = logging.LogRecord(
        name="test.exc",
        level=logging.ERROR,
        pathname="test.py",
        lineno=1,
        msg="error happened",
        args=None,
        exc_info=exc_info,
    )
    filt = RequestIdFilter()
    filt.filter(record)

    output = formatter.format(record)
    parsed = json.loads(output)

    assert "exception" in parsed
    assert "ValueError" in parsed["exception"]
