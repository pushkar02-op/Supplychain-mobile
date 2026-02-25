from app.core.config import settings
from app.core.exceptions import AppException
from fastapi import UploadFile


async def validate_upload_size(file: UploadFile):
    """Read file contents and reject if over the configured size limit."""
    contents = await file.read()
    size = len(contents)

    max_bytes = settings.FILE_UPLOAD_MAX_MB * 1024 * 1024

    if size > max_bytes:
        raise AppException(
            status_code=413,
            detail="File too large",
        )

    await file.seek(0)
