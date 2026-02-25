import logging

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def check_db_ready(db: Session) -> bool:
    """Execute a lightweight query to verify database connectivity."""
    try:
        db.execute(text("SELECT 1"))
        return True
    except Exception:
        logger.warning("Database readiness check failed", exc_info=True)
        return False
