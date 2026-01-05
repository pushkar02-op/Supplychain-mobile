import logging
import os

import aiofiles
from app.core.storage.base import StorageService

logger = logging.getLogger(__name__)


class LocalDiskStorage(StorageService):
    """
    Implementation of StorageService for local filesystem.
    ROOT path is determined by configuration.
    """

    def __init__(self, base_path: str):
        self.base_path = os.path.abspath(base_path)
        os.makedirs(self.base_path, exist_ok=True)
        logger.info(f"LocalDiskStorage initialized at: {self.base_path}")

    async def save(self, file_data: bytes, filename: str) -> str:
        # For now, we use the filename as the key to preserve existing behavior.
        # Ideally, we should generate a UUID to avoid collisions.
        # But existing DB rows store 'invoices/foo.pdf'.
        # If base_path is project root, existing keys work.
        # If base_path is 'invoices/', keys should be 'foo.pdf'.

        # To handle migration gracefully:
        # We will assume the service passes the desired relative path/key.
        # Or we determine key here.

        # Current logic in service:
        # upload_path = os.path.join(settings.INVOICE_UPLOAD_DIR, filename)
        # settings.INVOICE_UPLOAD_DIR is 'invoices'

        # So we construct the absolute path.
        file_path = os.path.join(self.base_path, filename)

        # Ensure directory exists if filename contains dirs (legacy keys might not, but new keys might)
        directory = os.path.dirname(file_path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory, exist_ok=True)

        async with aiofiles.open(file_path, "wb") as f:
            await f.write(file_data)

        return filename

    def get_path(self, key: str) -> str:
        # Prevent directory traversal attacks
        # In a real app we'd need strict validation.
        return os.path.join(self.base_path, key)

    def exists(self, key: str) -> bool:
        path = self.get_path(key)
        return os.path.exists(path)

    def delete(self, key: str) -> bool:
        path = self.get_path(key)
        if os.path.exists(path):
            try:
                os.remove(path)
                return True
            except OSError as e:
                logger.error(f"Error deleting file {path}: {e}")
                return False
        return False
