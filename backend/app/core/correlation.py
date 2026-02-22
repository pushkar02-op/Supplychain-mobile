from contextvars import ContextVar, Token
from typing import Optional
from uuid import uuid4

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

CORRELATION_ID_HEADER = "X-Correlation-ID"
_correlation_id_ctx_var: ContextVar[Optional[str]] = ContextVar(
    "correlation_id", default=None
)


def get_correlation_id() -> Optional[str]:
    return _correlation_id_ctx_var.get()


def set_correlation_id(correlation_id: str) -> Token:
    return _correlation_id_ctx_var.set(correlation_id)


def reset_correlation_id(token: Token) -> None:
    _correlation_id_ctx_var.reset(token)


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        correlation_id = request.headers.get(CORRELATION_ID_HEADER) or str(uuid4())
        token = set_correlation_id(correlation_id)
        request.state.correlation_id = correlation_id

        try:
            response = await call_next(request)
        finally:
            reset_correlation_id(token)

        response.headers[CORRELATION_ID_HEADER] = correlation_id
        return response
