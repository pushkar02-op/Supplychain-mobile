from app.core.exceptions import AppException
from app.db.session import get_db
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    return {"status": "ok"}


@router.get("/ready")
def ready(db: Session = Depends(get_db)):
    from app.services.health import check_db_ready

    if not check_db_ready(db):
        raise AppException(
            detail="Service not ready",
            status_code=503,
        )
    return {"status": "ready"}
