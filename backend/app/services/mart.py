from app.db.models.mart import Mart
from app.db.schemas.mart import MartCreate
from sqlalchemy.orm import Session


def create_mart(db: Session, mart: MartCreate) -> Mart:
    mart_data = mart.dict()
    # Pydantic might have 'created_by' in defaults, but we need to resolve it.
    # Assuming MartCreate *might* have it, or it's passed implicitly?
    # Actually, MartCreate likely doesn't have created_by in the input schema usually.
    # But if it does (implicit), we must catch it.
    # Let's see if we can get it from context. If not, maybe it's missing from the arg list?
    # WAIT: Standard `create_mart` doesn't take `created_by` argument in the current file!
    # I must ADD `created_by: Optional[str] = None` to the signature to support it,
    # OR if it's in `mart.dict()`, extract it.
    # For now, let's extract it if present, otherwise default to "system" or None.

    raw_created_by = mart_data.pop("created_by", None)

    from app.utils.audit import resolve_user_audit

    user_name, user_id = resolve_user_audit(db, raw_created_by)

    db_mart = Mart(
        **mart_data, created_by=user_name, created_by_id=user_id, updated_by=user_name
    )
    db.add(db_mart)
    db.commit()
    db.refresh(db_mart)
    return db_mart


def get_marts_by_company(db: Session, company_id: int):
    return db.query(Mart).filter(Mart.company_id == company_id).all()
