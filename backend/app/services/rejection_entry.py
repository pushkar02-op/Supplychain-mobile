from datetime import date
from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.db.models.rejection_entry import RejectionEntry
from app.db.models.batch import Batch
from app.db.schemas.rejection_entry import RejectionEntryCreate
from sqlalchemy.exc import SQLAlchemyError


def create_rejection_entry(
    db: Session,
    entry: RejectionEntryCreate,
    created_by: Optional[str] = None
) -> RejectionEntry:
    batch = db.query(Batch).filter(Batch.id == entry.batch_id).first()

    if batch is None:
        raise HTTPException(status_code=404, detail="Batch not found")

    if batch.quantity < entry.quantity:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot reject {entry.quantity}. Only {batch.quantity} available in batch."
        )

    db_entry = RejectionEntry(
        batch_id=entry.batch_id,
        quantity=entry.quantity,
        reason=entry.reason,
        rejection_date=entry.rejection_date,
        rejected_by=entry.rejected_by,
        unit=batch.unit,
        item_id=batch.item_id,
        created_by=created_by,
        updated_by=created_by
    )

    try:
        db.add(db_entry)
        batch.quantity -= entry.quantity
        db.commit()
        db.refresh(db_entry)
        return db_entry
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Error creating rejection entry")
    

def get_all_rejections(db: Session) -> List[RejectionEntry]:
    return db.query(RejectionEntry).order_by(RejectionEntry.rejection_date.desc()).all()

def get_rejections_by_date_and_items(
    db: Session,
    rejection_date: date,
    item_ids: Optional[List[int]] = None
) -> List[RejectionEntry]:
    query = db.query(RejectionEntry).filter(RejectionEntry.rejection_date == rejection_date)

    if item_ids:
        query = query.filter(RejectionEntry.item_id.in_(item_ids))

    return query.order_by(RejectionEntry.created_at.desc()).all()