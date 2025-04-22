from typing import List, Optional
from sqlalchemy.orm import Session
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.batch import Batch
from app.db.schemas.rejection_entry import RejectionEntryCreate

def create_rejection_entry(
    db: Session,
    entry: RejectionEntryCreate,
    created_by: Optional[str] = None
) -> RejectionEntry:
    db_entry = RejectionEntry(
        **entry.dict(),
        created_by=created_by,
        updated_by=created_by,
    )
    db.add(db_entry)

    if entry.batch_id:
        batch = db.query(Batch).get(entry.batch_id)
        if batch is None:
            raise ValueError("Invalid batch_id")
        batch.quantity -= entry.quantity

    db.commit()
    db.refresh(db_entry)
    return db_entry

def get_all_rejections(db: Session) -> List[RejectionEntry]:
    return db.query(RejectionEntry).all()
