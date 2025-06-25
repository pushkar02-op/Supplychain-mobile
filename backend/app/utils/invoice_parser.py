"""
Utility functions for invoice PDF parsing.
Handles extraction, normalization, and cleaning of invoice tables.
"""

import logging
import re
from datetime import datetime
from typing import Tuple

import pandas as pd
import pdfplumber

from app.core.exceptions import AppException
from app.utils.invoice_parser_reliance import (
    clean_and_rename,
    extract_raw_table,
    find_store_and_date,
    normalize_rows,
    process_pdf_reliance,
)
from app.utils.invoice_parser_blinkit import (
    process_pdf_blinkit,
)

logger = logging.getLogger(__name__)


def detect_invoice_format(input_file: str) -> str:
    """
    Detects the invoice format based on the content of the first page.

    Args:
        input_file (str): Path to the PDF file.

    Returns:
        str: Invoice format identifier (e.g., "seller_a", "seller_b").

    Raises:
        AppException: If the invoice format is unknown or cannot be determined.
    """
    logger.info(f"Detecting invoice format for {input_file}")
    with pdfplumber.open(input_file) as pdf:
        first_page_text = pdf.pages[0].extract_text()
        if "Zomato" in first_page_text:
            logger.info("Detected format: Seller A")
            return "Zomato"
        elif "Reliance" in first_page_text:
            logger.info("Detected format: Seller B")
            return "Reliance"
        # Add more rules as needed
    logger.error("Unknown invoice format")
    raise AppException("Unknown invoice format", status_code=400)


def process_pdf(input_file: str) -> Tuple[pd.DataFrame, datetime, str]:
    """
    Full pipeline: extract, normalize, clean, and return invoice table.
    """
    logger.info(f"✅✅Processing PDF: {input_file}")
    fmt = detect_invoice_format(input_file)
    if fmt == "Reliance":
        return process_pdf_reliance(input_file)
    elif fmt == "Zomato":
        return process_pdf_blinkit(input_file)
    else:
        raise AppException("Unsupported invoice format", status_code=400)
