"""
Custom exceptions and global exception handlers for the application.
"""

import logging
import re
from typing import Any

from fastapi import HTTPException, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.status import HTTP_500_INTERNAL_SERVER_ERROR

logger = logging.getLogger(__name__)


# Base AppException for domain-level errors
class AppException(Exception):
    _RULE_ID_PATTERN = re.compile(r"^[A-Z]{3}-\d{3}$")
    _DEFAULT_RULE_ID = "GEN-000"

    def __init__(
        self,
        detail: str = None,
        status_code: int = 400,
        rule_id: str = None,
        metadata: dict = None,
        message: str = None,
        **kwargs,
    ):
        resolved_detail = detail if detail is not None else message
        if resolved_detail is None:
            resolved_detail = "Application error"

        extra = kwargs.pop("extra", None)
        resolved_rule_id = rule_id
        resolved_metadata = {}

        if isinstance(extra, dict):
            extra_copy = dict(extra)
            if resolved_rule_id is None:
                resolved_rule_id = extra_copy.pop("rule_id", None)
            nested_metadata = extra_copy.pop("metadata", None)
            if isinstance(nested_metadata, dict):
                resolved_metadata.update(nested_metadata)
            resolved_metadata.update(extra_copy)

        if metadata:
            resolved_metadata.update(metadata)

        if kwargs:
            resolved_metadata.update(kwargs)

        if resolved_rule_id is None:
            resolved_rule_id = self._DEFAULT_RULE_ID
        if not self._RULE_ID_PATTERN.match(resolved_rule_id):
            raise ValueError("rule_id must match ^[A-Z]{3}-\\d{3}$")

        super().__init__(resolved_detail)
        self.message = resolved_detail
        self.detail = resolved_detail
        self.status_code = status_code
        self.rule_id = resolved_rule_id
        self.metadata = resolved_metadata
        self.extra = {"rule_id": resolved_rule_id, **resolved_metadata}


class UOMConfigurationError(AppException):
    """Raised when UOM configuration (default UOM or conversion factor) is missing or invalid."""

    def __init__(self, detail: str, rule_id: str = None, metadata: dict = None):
        super().__init__(
            detail=detail, status_code=409, rule_id=rule_id, metadata=metadata
        )  # 409 Conflict suitable for config mismatch


def _to_envelope(detail: Any, rule_id: str, metadata: Any = None) -> dict:
    return {
        "detail": str(detail),
        "rule_id": rule_id,
        "metadata": metadata if isinstance(metadata, dict) else {},
    }


# Register handlers function
def register_exception_handlers(app):
    @app.exception_handler(UOMConfigurationError)
    async def uom_config_exception_handler(
        request: Request, exc: UOMConfigurationError
    ):
        logger.warning(f"UOM Configuration Error: {exc.message}")
        content = jsonable_encoder(_to_envelope(exc.detail, exc.rule_id, exc.metadata))
        return JSONResponse(
            status_code=exc.status_code,
            content=content,
        )

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException):
        logger.warning(f"AppException: {exc.message}")
        content = jsonable_encoder(_to_envelope(exc.detail, exc.rule_id, exc.metadata))
        return JSONResponse(status_code=exc.status_code, content=content)

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ):
        logger.warning(f"Validation Error: {exc.errors()}")
        content = jsonable_encoder(
            _to_envelope("Request validation failed", "GEN-422", {})
        )
        return JSONResponse(status_code=422, content=content)

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        logger.warning(f"HTTPException: {exc.detail}")
        detail = exc.detail
        metadata = {}
        if isinstance(exc.detail, dict):
            detail = exc.detail.get("detail", exc.detail)
            metadata = exc.detail.get("metadata", {}) or {}
        content = jsonable_encoder(_to_envelope(detail, "GEN-HTTP", metadata))
        return JSONResponse(status_code=exc.status_code, content=content)

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception(f"Unhandled Exception: {exc}")
        content = jsonable_encoder(
            _to_envelope(
                "Internal server error. Please contact support.", "GEN-500", {}
            )
        )
        return JSONResponse(
            status_code=HTTP_500_INTERNAL_SERVER_ERROR,
            content=content,
        )
