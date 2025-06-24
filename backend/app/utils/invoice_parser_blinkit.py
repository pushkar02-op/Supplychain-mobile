import logging
from datetime import datetime
from typing import Tuple
import re
import pandas as pd
import pdfplumber

from app.core.exceptions import AppException

logger = logging.getLogger(__name__)


def extract_raw_text_lines(input_file: str) -> list:
    """
    Extracts all text lines from all pages of the PDF.
    """
    logger.info(f"Extracting raw text from {input_file}")
    lines = []
    try:
        with pdfplumber.open(input_file) as pdf:
            for page_number, page in enumerate(pdf.pages, start=1):
                text = page.extract_text()
                if text:
                    page_lines = text.split("\n")
                    lines.extend(page_lines)
                    logger.debug(
                        f"Page {page_number}: extracted {len(page_lines)} lines"
                    )
    except Exception as e:
        logger.exception("Failed to extract raw text")
        raise AppException(f"Error reading PDF: {e}", status_code=500)
    return lines


def find_store_and_date_from_lines(lines: list) -> Tuple[str, datetime]:
    # Store name is in line 11 (index 10), inside first ()
    store_line = lines[10]
    store_match = re.search(r"\(([^)]+)\)", store_line)
    if not store_match:
        raise Exception(f"Could not find store name in: {store_line}")
    store_name = store_match.group(1).strip()

    # Date is in line 22 (index 21), extract first date in "06 Jun 2025" format
    date_line = lines[21]
    date_match = re.search(r"\b\d{2} [A-Za-z]{3} \d{4}\b", date_line)
    if not date_match:
        raise Exception(f"Could not find date in: {date_line}")
    date_str = date_match.group(0)
    invoice_date = datetime.strptime(date_str, "%d %b %Y")

    return store_name, invoice_date


def normalize_rows_from_lines(lines: list) -> list:
    """
    Extracts item rows from lines, starting after the header and stopping before summary.
    """
    # Find header row index (e.g., the line that starts with "Product No" or similar)
    header_idx = next((i for i, line in enumerate(lines) if "Product No" in line), None)
    if header_idx is None:
        raise Exception("Could not find header row in lines.")

    # Find end index (first line containing "Amount Chargeable (in words)")
    end_idx = next(
        (i for i, line in enumerate(lines) if "Amount Chargeable (in words)" in line),
        len(lines),
    )

    # Extract item lines (header + data)
    item_lines = lines[header_idx : end_idx - 2]  # -2 if you want to stop 2 lines before

    # Print the item lines for inspection
    print("\n--- Item lines preview ---")
    for i, line in enumerate(item_lines):
        print(f"{i}: {line}")
    print("--- End of item lines preview ---\n")

    # Optionally, split each line into columns using regex or str.split()
    # Example: [line.split() for line in item_lines]

    return item_lines


def clean_and_rename(
    rows: pd.DataFrame, store: str, invoice_date: datetime
) -> pd.DataFrame:
    """
    Cleans and renames columns for consistency.
    """
    # TODO: Implement cleaning and renaming logic
    raise NotImplementedError("Blinkit cleaning/renaming not implemented.")


def process_pdf_blinkit(input_file: str) -> Tuple[pd.DataFrame, datetime, str]:
    logger.info(f"Processing Blinkit PDF: {input_file}")
    lines = extract_raw_text_lines(input_file)

    # Now, pass these lines to your new parsing functions:
    store, invoice_date = find_store_and_date_from_lines(lines)
    rows = normalize_rows_from_lines(lines)
    clean_df = clean_and_rename(rows, store, invoice_date)
    logger.info(f"Processed Blinkit PDF for store {store} on {invoice_date.date()}")
    return clean_df, invoice_date, store
