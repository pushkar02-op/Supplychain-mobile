"""
Tests for file upload size limits.
Verifies that uploads exceeding FILE_UPLOAD_MAX_MB are rejected with 413.
"""

import asyncio
import io

import pytest
from fastapi import UploadFile

from app.core.config import settings
from app.core.exceptions import AppException
from app.utils.file_validation import validate_upload_size


def _make_upload_file(size_bytes: int, filename: str = "test.pdf") -> UploadFile:
    """Create a fake UploadFile of the given size."""
    header = b"%PDF-1.4 fake"
    content = header + b"\x00" * max(0, size_bytes - len(header))
    return UploadFile(filename=filename, file=io.BytesIO(content))


def test_upload_over_limit_rejected(monkeypatch):
    """File larger than FILE_UPLOAD_MAX_MB must raise AppException(413)."""
    monkeypatch.setattr(settings, "FILE_UPLOAD_MAX_MB", 1)

    oversized = _make_upload_file(1 * 1024 * 1024 + 1)  # 1 MB + 1 byte

    with pytest.raises(AppException) as exc_info:
        asyncio.get_event_loop().run_until_complete(validate_upload_size(oversized))

    assert exc_info.value.status_code == 413
    assert exc_info.value.detail == "File too large"


def test_upload_under_limit_accepted(monkeypatch):
    """File under the limit must pass validation without error."""
    monkeypatch.setattr(settings, "FILE_UPLOAD_MAX_MB", 10)

    small = _make_upload_file(100)  # 100 bytes

    # Should not raise
    asyncio.get_event_loop().run_until_complete(validate_upload_size(small))

    # Verify file pointer was reset to start
    content = asyncio.get_event_loop().run_until_complete(small.read())
    assert len(content) == 100
