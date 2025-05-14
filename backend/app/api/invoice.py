import os
from fastapi import APIRouter, HTTPException, Query, UploadFile, File, Depends, status
from sqlalchemy.orm import Session
from typing import List, Optional
from fastapi.responses import FileResponse
from app.services.invoice import (
    save_and_process_invoice,
    get_invoice_by_id,
    get_all_invoices,
    update_invoice,
    delete_invoice
)
from app.db.schemas.invoice import InvoiceRead, InvoiceUpdate
from app.db.session import get_db


router = APIRouter(prefix="/invoices", tags=["Invoices"])

@router.post("/upload", status_code=status.HTTP_201_CREATED ,summary="Upload one or more invoice PDFs",)
async def upload_invoices(
    files: List[UploadFile] = File(..., description="One or more PDF files"),
    db: Session = Depends(get_db)
):
    results = []
    for file in files:
        if not file.filename.endswith(".pdf"):
            results.append({"filename": file.filename, "success": False, "error": "Not a PDF"})
            continue
        result = await save_and_process_invoice(file, db=db, created_by="system")  # ✅ await
        results.append(result)
    return results

@router.get("/", response_model=List[InvoiceRead])
def read_invoices(
    invoice_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    mart_name: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return get_all_invoices(
        db,
        invoice_date=invoice_date,
        mart_name=mart_name,
        search=search
    )

@router.get("/{invoice_id}", response_model=InvoiceRead)
def read_invoice(invoice_id: int, db: Session = Depends(get_db)):
    invoice = get_invoice_by_id(db, invoice_id)
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return invoice


@router.put("/{invoice_id}", response_model=InvoiceRead)
def update_invoice_route(invoice_id: int, data: InvoiceUpdate, db: Session = Depends(get_db)):
    updated = update_invoice(db, invoice_id, data)
    if not updated:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return updated


@router.delete("/{invoice_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_invoice_route(invoice_id: int, db: Session = Depends(get_db)):
    if not delete_invoice(db, invoice_id):
        raise HTTPException(status_code=404, detail="Invoice not found")
    return None

@router.get(
    "/{invoice_id}/download",
    summary="Download the invoice PDF",
    response_class=FileResponse,
)
def download_invoice_pdf(invoice_id: int, db: Session = Depends(get_db)):
    invoice = get_invoice_by_id(db, invoice_id)
    print(invoice)
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    file_path = invoice.file_path
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Invoice file not found on server")

    return FileResponse(
        path=file_path,
        media_type="application/pdf",
        filename=os.path.basename(file_path),
    )