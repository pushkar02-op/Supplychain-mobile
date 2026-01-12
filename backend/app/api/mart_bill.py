"""
API endpoints for Mart Bill management.
This is the preferred endpoint for bill management.
Aliases logic from legacy /invoices.
"""

import logging
import os
from datetime import date
from typing import List, Optional

from app.core.auth import get_current_user
from app.core.exceptions import AppException
from app.db.schemas.mart_bill import MartBillRead, MartBillUpdate
from app.db.session import get_db
from app.services.mart_bill import (
    delete_mart_bill,
    get_mart_bill_by_id,
    get_mart_bills_paginated,
    replace_mart_bill_file,
    save_and_process_mart_bill,
    unverify_mart_bill,
    update_mart_bill,
    verify_mart_bill,
)
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse, JSONResponse
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/mart-bills", tags=["Mart Bills"])


@router.post(
    "/upload",
    status_code=status.HTTP_201_CREATED,
    summary="Upload Mart Bill PDFs",
    description="Uploads one or more mart bill PDF files and processes them.",
)
async def upload_mart_bills(
    files: List[UploadFile] = File(..., description="One or more PDF files"),
    db: Session = Depends(get_db),
) -> List[dict]:
    """
    Upload and process multiple mart bill PDFs.

    Args:
        files (List[UploadFile]): List of PDF files to upload.
        db (Session): Database session dependency.

    Returns:
        List[dict]: Processing results for each file.
    """
    logger.info(f"Uploading {len(files)} mart bill file(s)")
    results = []
    for file in files:
        if not file.filename.endswith(".pdf"):
            logger.warning(f"Skipped non-PDF file: {file.filename}")
            results.append(
                {"filename": file.filename, "success": False, "error": "Not a PDF"}
            )
            continue
        result = await save_and_process_mart_bill(file, db=db, created_by="system")
        results.append(result)
    return results


@router.get(
    "/",
    summary="List Mart Bills",
    description="Retrieve mart bills with optional date, mart, search, and pagination.",
)
def read_mart_bills(
    invoice_date: Optional[date] = Query(
        None, description="Filter by bill date (YYYY-MM-DD)"
    ),
    mart_id: Optional[int] = Query(None, description="Filter by mart id"),
    search: Optional[str] = Query(None, description="Search term"),
    skip: int = Query(0, ge=0, description="Items to skip"),
    limit: int = Query(20, ge=1, le=50, description="Items to return"),
    # Legacy support
    page: Optional[int] = Query(None, ge=1, description="Deprecated: Use skip/limit"),
    page_size: Optional[int] = Query(
        None, ge=1, le=100, description="Deprecated: Use skip/limit"
    ),
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    List mart bills with optional filters and pagination.
    Supports both offset-based (skip/limit) and page-based (page/page_size) pagination.

    Args:
        invoice_date (Optional[date]): Filter by bill date.
        mart_id (Optional[int]): Filter by mart id.
        search (Optional[str]): Search term.
        skip (int): Items to skip.
        limit (int): Items to return.
        page (Optional[int]): Legacy page number.
        page_size (Optional[int]): Legacy page size.
        db (Session): Database session dependency.

    Returns:
        JSONResponse: A response containing total, skip, limit, has_more, and items (results).
    """
    logger.info("Fetching mart bills")

    # Handle legacy pagination if provided
    if page is not None:
        effective_limit = page_size if page_size else limit
        effective_skip = (page - 1) * effective_limit
    else:
        effective_skip = skip
        effective_limit = limit

    return get_mart_bills_paginated(
        db=db,
        invoice_date=invoice_date,
        mart_id=mart_id,
        search=search,
        skip=effective_skip,
        limit=effective_limit,
    )


@router.get("/{bill_id}", response_model=MartBillRead, summary="Get Mart Bill by ID")
def read_mart_bill(bill_id: int, db: Session = Depends(get_db)) -> MartBillRead:
    """
    Retrieve a single mart bill by ID.

    Args:
        bill_id (int): Bill ID.
        db (Session): Database session dependency.

    Returns:
        MartBillRead: The bill record.

    Raises:
        AppException: If the bill is not found (404).
    """
    logger.info(f"Fetching mart bill id={bill_id}")
    bill = get_mart_bill_by_id(db, bill_id)
    if not bill:
        logger.error(f"Mart bill not found: id={bill_id}")
        raise AppException("Mart bill not found", status_code=404)
    return bill


@router.put("/{bill_id}", response_model=MartBillRead, summary="Update Mart Bill")
def update_mart_bill_route(
    bill_id: int, data: MartBillUpdate, db: Session = Depends(get_db)
) -> MartBillRead:
    """
    Update an existing mart bill.

    Args:
        bill_id (int): Bill ID.
        data (MartBillUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        MartBillRead: The updated bill.

    Raises:
        AppException: If the bill is not found (404).
    """
    logger.info(f"Updating mart bill id={bill_id}")
    updated = update_mart_bill(db, bill_id, data)
    if not updated:
        logger.error(f"Mart bill not found: id={bill_id}")
        raise AppException("Mart bill not found", status_code=404)
    return updated


@router.post("/{bill_id}/verify", response_model=MartBillRead)
def verify_mart_bill_endpoint(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Verify and lock a mart bill.
    """
    # Using username or full_name
    verifier_name = getattr(current_user, "full_name", None) or current_user.username
    bill = verify_mart_bill(db, invoice_id=bill_id, user_name=verifier_name)
    if not bill:
        raise HTTPException(status_code=404, detail="Mart bill not found")
    return bill


@router.post("/{bill_id}/unverify", response_model=MartBillRead)
def unverify_mart_bill_endpoint(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Unlock a mart bill (revert to NEEDS_REVIEW).
    """
    bill = unverify_mart_bill(db, invoice_id=bill_id)
    if not bill:
        raise HTTPException(status_code=404, detail="Mart bill not found")
    bill = unverify_mart_bill(db, invoice_id=bill_id)
    if not bill:
        raise HTTPException(status_code=404, detail="Mart bill not found")
    return bill


@router.post("/{bill_id}/replace-file", response_model=MartBillRead)
async def replace_mart_bill_file_endpoint(
    bill_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Replace the PDF file for a mart bill.
    Useful for fixing 404s or correcting uploads.
    Resets status to NEEDS_REVIEW.
    """
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed")

    user_name = getattr(current_user, "full_name", None) or current_user.username
    bill = await replace_mart_bill_file(
        db, invoice_id=bill_id, file=file, user_name=user_name
    )

    if not bill:
        raise HTTPException(status_code=404, detail="Mart bill not found")

    return bill


@router.delete(
    "/{bill_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Mart Bill"
)
def delete_mart_bill_route(bill_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete a mart bill by ID.

    Args:
        bill_id (int): Bill ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the bill is not found (404).
    """
    logger.info(f"Deleting mart bill id={bill_id}")
    if not delete_mart_bill(db, bill_id):
        logger.error(f"Mart bill not found: id={bill_id}")
        raise AppException("Mart bill not found", status_code=404)
    return None


@router.get(
    "/{bill_id}/download",
    response_class=FileResponse,
    summary="Download Mart Bill PDF",
)
def download_mart_bill_pdf(bill_id: int, db: Session = Depends(get_db)) -> FileResponse:
    """
    Download the PDF file for a given mart bill.

    Args:
        bill_id (int): Bill ID.
        db (Session): Database session dependency.

    Returns:
        FileResponse: PDF file response.

    Raises:
        AppException: If bill or file is not found (404).
    """
    logger.info(f"Downloading mart bill PDF id={bill_id}")
    bill = get_mart_bill_by_id(db, bill_id)
    if not bill:
        logger.error(f"Mart bill not found: id={bill_id}")
        raise AppException("Mart bill not found", status_code=404)

    file_path = bill.file_path
    # Use storage service to verify existence and get absolute path
    # Note: We import storage from services.mart_bill where it is initialized
    from app.services.mart_bill import storage

    if not storage.exists(file_path):
        logger.error(f"Mart bill file not found on server: {file_path}")
        raise AppException("Mart bill file not found on server", status_code=404)

    return FileResponse(
        path=storage.get_path(file_path),
        media_type="application/pdf",
        filename=os.path.basename(file_path),
    )
