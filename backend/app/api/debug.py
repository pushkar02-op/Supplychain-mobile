"""
Debug endpoints for UAT observability. Restricted to OWNER role.
"""

import json
import logging
import os
from typing import Optional

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from fastapi import APIRouter, Depends, Query

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/debug", tags=["Debug"])

LOG_FILE = os.path.join(os.getenv("LOG_DIR", "logs"), "app.log")


@router.get("/logs", summary="Fetch recent log entries")
def get_logs(
    lines: int = Query(100, ge=1, le=1000, description="Number of recent lines"),
    level: Optional[str] = Query(
        None, description="Filter by level: ERROR, WARNING, INFO, DEBUG"
    ),
    path_contains: Optional[str] = Query(
        None, description="Filter by request path substring"
    ),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> list[dict]:
    """Return the most recent log entries from the log file."""
    if not os.path.exists(LOG_FILE):
        return []
    with open(LOG_FILE, "r") as f:
        all_lines = f.readlines()
    results = []
    for line in all_lines[-lines:]:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if level and entry.get("level") != level.upper():
            continue
        if path_contains and path_contains not in entry.get("path", ""):
            continue
        results.append(entry)
    return results


@router.get("/logs/errors", summary="Fetch recent errors only")
def get_error_logs(
    lines: int = Query(500, ge=1, le=5000),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> list[dict]:
    """Return only ERROR and WARNING entries from the log file."""
    if not os.path.exists(LOG_FILE):
        return []
    with open(LOG_FILE, "r") as f:
        all_lines = f.readlines()
    results = []
    for line in all_lines[-lines:]:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("level") in ("ERROR", "WARNING"):
            results.append(entry)
    return results
