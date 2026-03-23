"""
Debug endpoints for UAT observability. Restricted to OWNER role.
"""

import json
import logging
import os
from datetime import datetime, timezone
from typing import Optional

from app.core.auth import require_role
from app.db.enums.role import Role
from app.db.models.user import User
from fastapi import APIRouter, Depends, Query

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/debug", tags=["Debug"])


@router.get("/logs", summary="Fetch recent log entries")
def get_logs(
    lines: int = Query(100, ge=1, le=1000, description="Number of recent lines"),
    level: Optional[str] = Query(
        None, description="Filter by level: ERROR, WARNING, INFO, DEBUG"
    ),
    path_contains: Optional[str] = Query(
        None, description="Filter by request path substring"
    ),
    source: Optional[str] = Query(
        None, description="Filter by source: 'backend', 'mobile', or None for both"
    ),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> list[dict]:
    """Return the most recent log entries merged from backend and mobile log files."""
    log_dir = os.getenv("LOG_DIR", "logs")
    backend_log = os.path.join(log_dir, "app.log")
    mobile_log = os.path.join(log_dir, "mobile.log")

    all_entries = []

    if source != "mobile" and os.path.exists(backend_log):
        with open(backend_log, "r") as f:
            for line in f.readlines()[-lines:]:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    entry["_source"] = "backend"
                    all_entries.append(entry)
                except json.JSONDecodeError:
                    pass

    if source != "backend" and os.path.exists(mobile_log):
        with open(mobile_log, "r") as f:
            for line in f.readlines()[-lines:]:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    entry["_source"] = "mobile"
                    all_entries.append(entry)
                except json.JSONDecodeError:
                    pass

    all_entries.sort(key=lambda e: e.get("timestamp", ""), reverse=True)

    results = []
    for entry in all_entries[:lines]:
        if level and entry.get("level", "").upper() != level.upper():
            continue
        if path_contains and (
            path_contains not in entry.get("path", "")
            and path_contains not in entry.get("message", "")
        ):
            continue
        results.append(entry)
    return results


@router.post("/mobile-logs", summary="Receive mobile log batch", status_code=201)
def receive_mobile_logs(
    entries: list[dict],
    current_user: User = Depends(require_role(Role.WORKER, Role.MANAGER, Role.OWNER)),
) -> dict:
    """Accept a batch of structured log entries from the mobile app."""
    mobile_log_file = os.path.join(os.getenv("LOG_DIR", "logs"), "mobile.log")
    os.makedirs(os.path.dirname(mobile_log_file), exist_ok=True)

    count = 0
    with open(mobile_log_file, "a") as f:
        for entry in entries:
            entry["_received_at"] = datetime.now(timezone.utc).isoformat()
            entry["_user"] = current_user.username
            f.write(json.dumps(entry, default=str) + "\n")
            count += 1

    logger.info("Received %d mobile log entries from %s", count, current_user.username)
    return {"received": count}


@router.get("/logs/errors", summary="Fetch recent errors only")
def get_error_logs(
    lines: int = Query(500, ge=1, le=5000),
    current_user: User = Depends(require_role(Role.OWNER)),
) -> list[dict]:
    """Return only ERROR and WARNING entries from both log files."""
    log_dir = os.getenv("LOG_DIR", "logs")
    backend_log = os.path.join(log_dir, "app.log")
    mobile_log = os.path.join(log_dir, "mobile.log")

    all_entries = []

    for log_path, src in [(backend_log, "backend"), (mobile_log, "mobile")]:
        if not os.path.exists(log_path):
            continue
        with open(log_path, "r") as f:
            for line in f.readlines()[-lines:]:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    if entry.get("level") in ("ERROR", "WARNING"):
                        entry["_source"] = src
                        all_entries.append(entry)
                except json.JSONDecodeError:
                    pass

    all_entries.sort(key=lambda e: e.get("timestamp", ""), reverse=True)
    return all_entries[:lines]
