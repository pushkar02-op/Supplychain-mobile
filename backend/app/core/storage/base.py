from abc import ABC, abstractmethod


class StorageService(ABC):
    """
    Abstract interface for file storage operations.
    Decouples business logic from physical storage (Local Disk, S3, etc).
    """

    @abstractmethod
    async def save(self, file_data: bytes, filename: str) -> str:
        """
        Save file content and return a unique storage key.

        Args:
            file_data: The binary content of the file.
            filename: The original filename (used for extension/reference).

        Returns:
            str: The storage key (relative path or ID) to be stored in DB.
        """
        pass

    @abstractmethod
    def get_path(self, key: str) -> str:
        """
        Get the absolute filesystem path for a given storage key.
        Useful for libraries requiring a file path (e.g. pdfplumber, FileResponse).

        Note: For remote storage (S3), this might need to download to a temp file first,
        or we might need to change consumers to accept file-like objects.
        For now, this assumes local availability or cache.
        """
        pass

    @abstractmethod
    def exists(self, key: str) -> bool:
        """
        Check if the file exists in storage.
        """
        pass

    @abstractmethod
    def delete(self, key: str) -> bool:
        """
        Delete the file from storage.
        """
        pass
