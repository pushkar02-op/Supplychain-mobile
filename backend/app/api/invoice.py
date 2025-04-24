from fastapi import APIRouter, HTTPException, UploadFile, File, Depends, status
from sqlalchemy.orm import Session
from typing import List

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
def read_all_invoices(db: Session = Depends(get_db)):
    return get_all_invoices(db)


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