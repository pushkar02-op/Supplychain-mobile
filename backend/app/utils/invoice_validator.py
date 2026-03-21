"""
PDF structure validation for invoices.
Validates structure before parsing to fail early with clear errors.
"""

import logging

import pdfplumber
from app.core.exceptions import AppException

logger = logging.getLogger(__name__)


def validate_invoice_structure(file_path: str) -> dict:
    """
    Validates PDF structure before parsing.

    Returns:
        {"is_valid": bool, "format": str | None, "errors": list[str]}

    Raises:
        AppException: If the PDF cannot be opened or has no pages.
    """
    errors = []

    try:
        with pdfplumber.open(file_path) as pdf:
            if not pdf.pages:
                raise AppException(
                    detail="Invoice PDF has no pages",
                    status_code=400,
                )

            page = pdf.pages[0]
            tables = page.extract_tables()

            if not tables or not tables[0]:
                errors.append("No table detected on first page")
                return {"is_valid": False, "format": None, "errors": errors}

            table = tables[0]

            # Strict row count — invoices always have header + data rows
            if len(table) < 5:
                errors.append("Unexpected table structure (too few rows)")

            # Strict column range — Zomato ~10 cols, Reliance ~8 cols
            first_row = table[0]
            if len(first_row) < 7:
                errors.append("Unexpected column count in invoice (too few)")
            elif len(first_row) > 12:
                errors.append("Unexpected column count in invoice (too many)")

            # Detect known format from page text
            text = page.extract_text() or ""

            if "Zomato" in text:
                detected_format = "ZOMATO_V1"
            elif "Reliance" in text:
                detected_format = "RELIANCE_V1"
            else:
                detected_format = None
                errors.append("Unknown invoice format")

            return {
                "is_valid": len(errors) == 0,
                "format": detected_format,
                "errors": errors,
            }

    except AppException:
        raise
    except Exception as e:
        raise AppException(
            detail=f"Failed to read invoice: {str(e)}",
            status_code=400,
        )
