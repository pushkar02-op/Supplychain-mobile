"""
Custom exceptions and global exception handlers for the application.
"""

import logging

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.status import HTTP_500_INTERNAL_SERVER_ERROR

logger = logging.getLogger(__name__)


# Base AppException for domain-level errors
class AppException(Exception):
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code


class UOMConfigurationError(AppException):
    """Raised when UOM configuration (default UOM or conversion factor) is missing or invalid."""

    def __init__(self, message: str):
        super().__init__(
            message=message, status_code=409
        )  # 409 Conflict suitable for config mismatch


# Register handlers function
def register_exception_handlers(app):
    @app.exception_handler(UOMConfigurationError)
    async def uom_config_exception_handler(
        request: Request, exc: UOMConfigurationError
    ):
        logger.warning(f"UOM Configuration Error: {exc.message}")
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.message, "error_code": "UOM_CONFIG_ERROR"},
        )

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException):
        logger.warning(f"AppException: {exc.message}")
        return JSONResponse(
            status_code=exc.status_code, content={"detail": exc.message}
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ):
        logger.warning(f"Validation Error: {exc.errors()}")
        return JSONResponse(status_code=422, content={"detail": exc.errors()})

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        logger.warning(f"HTTPException: {exc.detail}")
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception(f"Unhandled Exception: {exc}")
        return JSONResponse(
            status_code=HTTP_500_INTERNAL_SERVER_ERROR,
            content={"detail": "Internal server error. Please contact support."},
        )
