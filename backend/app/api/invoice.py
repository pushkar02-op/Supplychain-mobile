from fastapi import APIRouter, UploadFile, File, Depends, status
from sqlalchemy.orm import Session
from typing import List


from app.services.invoice import save_and_process_invoice
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
