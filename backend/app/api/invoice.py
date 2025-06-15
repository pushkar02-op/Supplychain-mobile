"""
API endpoints for invoice management.
Provides upload, retrieval, update, deletion, and download of invoices.
"""

import logging
import os
from fastapi import APIRouter, Depends, Query, UploadFile, File, status
from sqlalchemy.orm import Session
from typing import List, Optional
from fastapi.responses import FileResponse

from app.core.exceptions import AppException
from app.services.invoice import (
    save_and_process_invoice,
    get_invoice_by_id,
    get_all_invoices,
    update_invoice,
    delete_invoice,
)
from app.db.schemas.invoice import InvoiceRead, InvoiceUpdate
from app.db.session import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/invoices", tags=["Invoices"])


@router.post(
    "/upload",
    status_code=status.HTTP_201_CREATED,
    summary="Upload invoice PDFs",
    description="Uploads one or more invoice PDF files and processes them.",
)
async def upload_invoices(
    files: List[UploadFile] = File(..., description="One or more PDF files"),
    db: Session = Depends(get_db),
) -> List[dict]:
    """
    Upload and process multiple invoice PDFs.

    Args:
        files (List[UploadFile]): List of PDF files to upload.
        db (Session): Database session dependency.

    Returns:
        List[dict]: Processing results for each file.
    """
    logger.info(f"Uploading {len(files)} invoice file(s)")
    results = []
    for file in files:
        if not file.filename.endswith(".pdf"):
            logger.warning(f"Skipped non-PDF file: {file.filename}")
            results.append(
                {"filename": file.filename, "success": False, "error": "Not a PDF"}
            )
            continue
        result = await save_and_process_invoice(file, db=db, created_by="system")
        results.append(result)
        logger.info(results)
    return results


@router.get(
    "/",
    response_model=List[InvoiceRead],
    summary="List invoices",
    description="Retrieve all invoices, with optional date, mart name, or search filters.",
)
def read_invoices(
    invoice_date: Optional[str] = Query(
        None, description="Filter by invoice date (YYYY-MM-DD)"
    ),
    mart_name: Optional[str] = Query(None, description="Filter by mart name"),
    search: Optional[str] = Query(None, description="Search term"),
    db: Session = Depends(get_db),
) -> List[InvoiceRead]:
    """
    Retrieve all invoices with optional filters.

    Args:
        invoice_date (Optional[str]): Filter by date.
        mart_name (Optional[str]): Filter by mart name.
        search (Optional[str]): Search term.
        db (Session): Database session dependency.

    Returns:
        List[InvoiceRead]: List of invoice records.
    """
    logger.info("Fetching invoices")
    return get_all_invoices(
        db, invoice_date=invoice_date, mart_name=mart_name, search=search
    )


@router.get("/{invoice_id}", response_model=InvoiceRead, summary="Get invoice by ID")
def read_invoice(invoice_id: int, db: Session = Depends(get_db)) -> InvoiceRead:
    """
    Retrieve a single invoice by ID.

    Args:
        invoice_id (int): Invoice ID.
        db (Session): Database session dependency.

    Returns:
        InvoiceRead: The invoice record.

    Raises:
        AppException: If the invoice is not found (404).
    """
    logger.info(f"Fetching invoice id={invoice_id}")
    invoice = get_invoice_by_id(db, invoice_id)
    if not invoice:
        logger.error(f"Invoice not found: id={invoice_id}")
        raise AppException("Invoice not found", status_code=404)
    return invoice


@router.put("/{invoice_id}", response_model=InvoiceRead, summary="Update invoice")
def update_invoice_route(
    invoice_id: int, data: InvoiceUpdate, db: Session = Depends(get_db)
) -> InvoiceRead:
    """
    Update an existing invoice.

    Args:
        invoice_id (int): Invoice ID.
        data (InvoiceUpdate): Update data.
        db (Session): Database session dependency.

    Returns:
        InvoiceRead: The updated invoice.

    Raises:
        AppException: If the invoice is not found (404).
    """
    logger.info(f"Updating invoice id={invoice_id}")
    updated = update_invoice(db, invoice_id, data)
    if not updated:
        logger.error(f"Invoice not found: id={invoice_id}")
        raise AppException("Invoice not found", status_code=404)
    return updated


@router.delete(
    "/{invoice_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete invoice"
)
def delete_invoice_route(invoice_id: int, db: Session = Depends(get_db)) -> None:
    """
    Delete an invoice by ID.

    Args:
        invoice_id (int): Invoice ID.
        db (Session): Database session dependency.

    Raises:
        AppException: If the invoice is not found (404).
    """
    logger.info(f"Deleting invoice id={invoice_id}")
    if not delete_invoice(db, invoice_id):
        logger.error(f"Invoice not found: id={invoice_id}")
        raise AppException("Invoice not found", status_code=404)
    return None


@router.get(
    "/{invoice_id}/download",
    response_class=FileResponse,
    summary="Download invoice PDF",
)
def download_invoice_pdf(
    invoice_id: int, db: Session = Depends(get_db)
) -> FileResponse:
    """
    Download the PDF file for a given invoice.

    Args:
        invoice_id (int): Invoice ID.
        db (Session): Database session dependency.

    Returns:
        FileResponse: PDF file response.

    Raises:
        AppException: If invoice or file is not found (404).
    """
    logger.info(f"Downloading invoice PDF id={invoice_id}")
    invoice = get_invoice_by_id(db, invoice_id)
    if not invoice:
        logger.error(f"Invoice not found: id={invoice_id}")
        raise AppException("Invoice not found", status_code=404)

    file_path = invoice.file_path
    if not os.path.exists(file_path):
        logger.error(f"Invoice file not found on server: {file_path}")
        raise AppException("Invoice file not found on server", status_code=404)

    return FileResponse(
        path=file_path,
        media_type="application/pdf",
        filename=os.path.basename(file_path),
    )
