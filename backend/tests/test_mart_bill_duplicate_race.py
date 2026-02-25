"""
Test: MartBill duplicate file_hash protection via unique constraint.
Verifies that the IntegrityError-based race guard works correctly.
"""

from datetime import date

import pytest
from app.db.models.mart_bill import MartBill
from sqlalchemy.exc import IntegrityError


@pytest.fixture
def seed_mart_bill(db_session):
    """Insert a mart bill with a known file_hash."""
    bill = MartBill(
        invoice_date=date(2024, 1, 1),
        mart_id=1,
        warehouse_id=1,
        total_amount=100,
        file_path="invoices/test.pdf",
        file_hash="abc123deadbeef",
        created_by="test",
        updated_by="test",
        status="NEEDS_REVIEW",
    )
    db_session.add(bill)
    db_session.commit()
    db_session.refresh(bill)
    return bill


@pytest.mark.unit
def test_duplicate_mart_bill_file_hash_rejected(db_session, seed_mart_bill):
    """
    Attempting to insert a second MartBill with the same file_hash
    must be blocked by the unique constraint. The service layer catches
    this as IntegrityError and raises AppException(409).
    """
    duplicate = MartBill(
        invoice_date=date(2024, 2, 1),
        mart_id=1,
        warehouse_id=1,
        total_amount=200,
        file_path="invoices/test2.pdf",
        file_hash=seed_mart_bill.file_hash,  # Same hash -> collision
        created_by="test",
        updated_by="test",
        status="NEEDS_REVIEW",
    )
    db_session.add(duplicate)

    with pytest.raises(IntegrityError):
        db_session.commit()

    db_session.rollback()

    # Verify only one row exists
    count = db_session.query(MartBill).filter_by(file_hash="abc123deadbeef").count()
    assert count == 1, f"Expected 1 row, got {count}"
