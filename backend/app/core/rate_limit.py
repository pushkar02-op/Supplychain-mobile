import os

from slowapi import Limiter
from slowapi.util import get_remote_address

rate_limit_enabled = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"

limiter = Limiter(key_func=get_remote_address, enabled=rate_limit_enabled)
