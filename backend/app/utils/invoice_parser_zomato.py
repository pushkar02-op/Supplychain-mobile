"""
PDF parser for AG AGRO / Zomato Hyperpure invoices.

Structure (from bill_structure.json):
  - Page 1 : 10-col table with header metadata + first batch of items
  - Pages 2–5 : 7-col table, pure item rows, header row repeated on each page
  - Columns (pages 2-5): Sl No. | Product Name | HSN | Qty.Del. | Price Per Unit | UoM | Total
  - Store  : row_index=1, cells[0] → "Outlet Name : <NAME>\nPhone..."
  - Date   : row_index=2, cells[4] → "Invoice Date\nDD-MM-YYYY"
  - Items end when cells[0] == "Total"

Returns the same interface as process_pdf_reliance:
    (clean_df, invoice_date, store)
"""

import logging
import re
from datetime import datetime
from typing import Tuple

import pandas as pd
import pdfplumber
from app.core.exceptions import AppException

logger = logging.getLogger(__name__)

# ── Column indices for the clean 7-col item table (pages 2-5) ─────────────
# Also used for page-1 item rows after we normalise them (see _extract_page1)
_COL_SL = 0
_COL_NAME = 1
_COL_HSN = 2
_COL_QTY = 3
_COL_PRICE = 4
_COL_UOM = 5
_COL_TOTAL = 6

_HEADER_MARKER = "Sl\nNo."  # first cell of every repeated header row
_TOTAL_MARKER = "Total"  # first cell of the grand-total row on last page


# ── Helpers ────────────────────────────────────────────────────────────────


def _extract_store_and_date(page1_table: list) -> Tuple[str, datetime]:
    """
    Pulls store name and invoice date from page-1 metadata rows.

    Row 1, cell 0 : "Outlet Name : AG AGRO\nPhone number : ..."
    Row 2, cell 4 : "Invoice Date\nDD-MM-YYYY"
    """
    # ── Store ──────────────────────────────────────────────────────────────
    # Row 5, cell 0: "Bill To: Zomato Hyperpure Pvt. Ltd. (CPC-BR-BHAGALPURX)\n..."
    # We want the value inside the parentheses on the "Bill To:" line.
    try:
        bill_to_cell = page1_table[5][0] or ""
        match = re.search(r"Bill To:.*\(([^)]+)\)", bill_to_cell)
        store = match.group(1).strip().replace(" ", "_") if match else "UNKNOWN_STORE"
        logger.debug(f"Found store: {store}")
    except Exception as e:
        logger.exception("Failed to extract store name")
        raise AppException(
            f"Could not locate store name in 'Bill To:' line: {e}", status_code=500
        )

    # ── Invoice date ───────────────────────────────────────────────────────
    try:
        # Row index 2, cell index 4: "Invoice Date\nDD-MM-YYYY"
        date_cell = page1_table[2][4] or ""
        date_txt = re.search(r"(\d{2}-\d{2}-\d{4})", date_cell).group(1)
        invoice_date = datetime.strptime(date_txt, "%d-%m-%Y")
        logger.debug(f"Found invoice date: {invoice_date.date()}")
    except Exception as e:
        logger.exception("Failed to parse invoice date")
        raise AppException(f"Error parsing invoice date: {e}", status_code=500)

    return store, invoice_date


def _is_header_row(row: list) -> bool:
    """True if this is a repeated column-header row."""
    return (row[0] or "").strip() == _HEADER_MARKER


def _is_total_row(row: list) -> bool:
    """True if this is the grand-total sentinel row."""
    return (row[0] or "").strip() == _TOTAL_MARKER


def _normalise_page1_items(page1_table: list) -> list[list]:
    """
    Page 1 has a 10-column table where item rows have nulls padding out
    the extra columns.  The columns we care about map as follows:

        10-col index : 0=Sl, 1=ProductName, 2=null, 3=HSN, 4=null,
                       5=Qty, 6=PricePerUnit, 7=null, 8=UoM, 9=Total

    We remap to the same 7-col order used by pages 2-5.
    Row index 8 is the header row; rows 9+ are items.
    """
    items = []
    for row in page1_table[9:]:  # skip metadata rows 0-7 and header row 8
        if _is_total_row(row):
            break
        if row[0] is None:  # continuation / null row — skip
            continue
        remapped = [
            row[0],  # Sl No.
            row[1],  # Product Name
            row[3],  # HSN
            row[5],  # Qty.Del.
            row[6],  # Price Per Unit
            row[8],  # UoM
            row[9],  # Total
        ]
        items.append(remapped)
    return items


def _collect_all_item_rows(pdf) -> list[list]:
    """
    Iterates every page, skips header rows, stops at Total row,
    returns a flat list of raw 7-element item rows.
    """
    all_rows = []

    for page_num, page in enumerate(pdf.pages, start=1):
        tbl = page.extract_table()
        if not tbl:
            logger.warning(f"Page {page_num}: no table found, skipping")
            continue

        logger.debug(f"Page {page_num}: {len(tbl)} rows × {len(tbl[0])} cols")

        if page_num == 1:
            # Special handling — normalise 10-col page-1 rows to 7-col
            all_rows.extend(_normalise_page1_items(tbl))
        else:
            # Pages 2-5: clean 7-col table
            for row in tbl:
                if _is_header_row(row):
                    continue
                if _is_total_row(row):
                    break
                # skip any fully-null rows
                if all(c is None for c in row):
                    continue
                all_rows.append(row)

    logger.info(f"Collected {len(all_rows)} item rows across all pages")
    return all_rows


# ── Main pipeline ──────────────────────────────────────────────────────────


def extract_raw_table_agro(input_file: str):
    """Opens the PDF and returns (page1_table, all_item_rows)."""
    logger.info(f"Opening PDF: {input_file}")
    try:
        with pdfplumber.open(input_file) as pdf:
            page1_table = pdf.pages[0].extract_table()
            if not page1_table:
                raise AppException(
                    "Page 1 table is empty — cannot extract metadata",
                    status_code=500,
                )
            all_item_rows = _collect_all_item_rows(pdf)
    except AppException:
        raise
    except Exception as e:
        logger.exception("Failed to open/parse PDF")
        raise AppException(f"Error reading PDF: {e}", status_code=500)

    return page1_table, all_item_rows


def _make_item_code(name: str) -> str:
    """
    Generates a stable 8-character item code from the cleaned item name.

    Steps:
      1. Strip BH prefix
      2. Take everything before the first comma (drop weight/qty suffix)
      3. Lowercase + strip whitespace → canonical form
      4. MD5 hash → take first 8 hex chars (uppercase)

    Same item always produces the same code across all bills.

    Examples:
      "BH-Garlic, 500 gm"            → "A3F2B1C9" (stable)
      "BH- Garlic, 200 gm"           → "A3F2B1C9" (same — prefix/qty ignored)
      "BH - Fresh Green Chilli, 50g" → "D7E4A2F1" (stable)
    """
    import hashlib

    s = name.strip()
    # Strip BH prefix
    s = re.sub(r"^BH\s*-?\s*", "", s, flags=re.IGNORECASE).strip()
    # Drop weight/qty suffix after first comma
    s = s.split(",")[0].strip().lower()
    # 8-char uppercase hex hash
    return hashlib.md5(s.encode()).hexdigest()[:8].upper()


def build_dataframe(
    item_rows: list[list],
    store: str,
    invoice_date: datetime,
) -> pd.DataFrame:
    """
    Converts raw item rows into a typed, cleaned DataFrame that matches
    the schema returned by process_pdf_reliance.

    Output columns:
        HSN_CODE | ITEM_CODE | Item | Quantity | UOM | Price | Total | Date | StoreName
    """
    if not item_rows:
        raise AppException("No item rows extracted from PDF", status_code=500)

    df = pd.DataFrame(
        item_rows,
        columns=["Sl_No", "Item", "HSN_CODE", "Quantity", "Price", "UOM", "Total"],
    )

    # Drop serial-number column — not in the output schema
    df = df.drop(columns=["Sl_No"])

    # Generate a unique item code from the product name
    df.insert(0, "ITEM_CODE", df["Item"].apply(_make_item_code))

    # Add metadata columns
    df["Date"] = invoice_date
    df["StoreName"] = store

    # ── String cleaning ────────────────────────────────────────────────────
    for col in ("Total", "Quantity", "Price"):
        df[col] = df[col].astype(str).str.replace(",", "", regex=False).str.strip()

    # Clean UoM — remove embedded newlines ("Per\npiece" → "Per piece")
    df["UOM"] = df["UOM"].astype(str).str.replace("\n", " ", regex=False).str.strip()

    # Clean Item — remove embedded newlines within product names
    df["Item"] = df["Item"].astype(str).str.replace("\n", " ", regex=False).str.strip()

    # ── Type conversion ────────────────────────────────────────────────────
    try:
        df = df.astype({"Quantity": "float", "Price": "float", "Total": "float"})
    except Exception as e:
        logger.exception("Failed to cast numeric columns")
        raise AppException(f"Type conversion error: {e}", status_code=500)

    df = df.round({"Quantity": 2, "Price": 2, "Total": 2})

    # ── Final column order to match reliance output ────────────────────────
    df = df[
        [
            "HSN_CODE",
            "ITEM_CODE",
            "Item",
            "Quantity",
            "UOM",
            "Price",
            "Total",
            "Date",
            "StoreName",
        ]
    ]

    logger.debug(f"DataFrame built: {len(df)} rows")
    return df


def process_pdf_zomato(input_file: str):
    """
    Public entry point — mirrors process_pdf_reliance signature exactly.

    Returns:
        (clean_df, invoice_date, store)
    """
    page1_table, item_rows = extract_raw_table_agro(input_file)
    store, invoice_date = _extract_store_and_date(page1_table)
    clean_df = build_dataframe(item_rows, store, invoice_date)

    logger.info(
        f"Processed AG AGRO PDF: store={store}, "
        f"date={invoice_date.date()}, rows={len(clean_df)}"
    )
    return clean_df, invoice_date, store
