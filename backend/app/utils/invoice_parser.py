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

logger = logging.getLogger(__name__)


def extract_raw_table(input_file: str) -> pd.DataFrame:
    """
    Extracts all table rows from every page of a PDF.

    Args:
        input_file (str): Path to the PDF file.

    Returns:
        pd.DataFrame: Raw rows as a DataFrame.

    Raises:
        AppException: If the PDF cannot be opened or parsed.
    """
    logger.info(f"Extracting raw table from {input_file}")
    rows = []
    try:
        with pdfplumber.open(input_file) as pdf:
            for page_number, page in enumerate(pdf.pages, start=1):
                tbl = page.extract_table()
                if tbl:
                    rows.extend(tbl)
                    logger.debug(f"Page {page_number}: extracted {len(tbl)} rows")
    except Exception as e:
        logger.exception("Failed to extract raw table")
        raise AppException(f"Error reading PDF: {e}", status_code=500)
    return pd.DataFrame(rows)


def find_store_and_date(df: pd.DataFrame) -> Tuple[str, datetime]:
    """
    Finds the store name and invoice date from the raw DataFrame.

    Args:
        df (pd.DataFrame): Raw table DataFrame.

    Returns:
        Tuple[str, datetime]: (store_name, invoice_date)

    Raises:
        AppException: If store or date cannot be found or parsed.
    """
    logger.info("Finding store name and invoice date")
    # find store
    for idx, row in df.iterrows():
        if "Site Name" in row.values:
            col = row[row == "Site Name"].index[0]
            store = df.iat[idx + 1, col].strip().replace(" ", "_")
            logger.debug(f"Found store: {store}")
            break
    else:
        logger.error("Site Name not found in PDF")
        raise AppException("Could not locate 'Site Name' in invoice", status_code=500)

    # find date
    try:
        raw_text = df.iat[0, 2]
        date_txt = re.search(r"(\d{2}\.\d{2}\.\d{4})", raw_text).group(1)
        invoice_date = datetime.strptime(date_txt, "%d.%m.%Y")
        logger.debug(f"Found invoice date: {invoice_date.date()}")
    except Exception as e:
        logger.exception("Failed to parse invoice date")
        raise AppException(f"Error parsing date: {e}", status_code=500)

    return store, invoice_date


def normalize_rows(df: pd.DataFrame) -> pd.DataFrame:
    """
    Removes header repeats and trailing totals, preserving only the item rows.

    Args:
        df (pd.DataFrame): Raw table DataFrame.

    Returns:
        pd.DataFrame: Normalized rows.
    """
    logger.info("Normalizing rows")
    working = df.iloc[8:].copy()  # drop top metadata
    # retain header row once
    first = working[0].tolist().index("Sr.No")
    header = working.iloc[first : first + 1]
    body = working[working[0] != "Sr.No"]
    working = pd.concat([header, body]).reset_index(drop=True)
    # drop trailing grand total
    if "Grand Total of Qty" in working[0].values:
        end = working[working[0] == "Grand Total of Qty"].index[0]
        working = working.iloc[:end]
    logger.debug(f"Normalized to {len(working)} rows")
    return working


def clean_and_rename(
    df: pd.DataFrame, store: str, invoice_date: datetime
) -> pd.DataFrame:
    """
    Cleans, types, and renames columns for the invoice DataFrame.

    Args:
        df (pd.DataFrame): Normalized rows.
        store (str): Store name.
        invoice_date (datetime): Invoice date.

    Returns:
        pd.DataFrame: Cleaned DataFrame with proper types.
    """
    logger.info("Cleaning and renaming DataFrame")
    df["StoreName"] = store
    df["Date"] = invoice_date

    # drop unwanted columns
    df = df.drop(columns=[0, 6, 8, 9], errors="ignore")
    # remove header row
    df = df.iloc[1:].copy()
    df.columns = [
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

    # string cleaning
    for col in ("Total", "Quantity", "Price"):
        df[col] = df[col].str.replace(",", "", regex=False)
    df["Item"] = (
        df["Item"]
        .str.replace(r"\n\d{2}\.\d{2}\.\d{4}\n\w{4}$", "", regex=True)
        .str.strip("._/\n")
    )
    df["HSN_CODE"] = df["HSN_CODE"].str.replace("\n", "", regex=False)
    df["ITEM_CODE"] = df["ITEM_CODE"].str.split("\n").str[0]

    # type conversion
    try:
        df = df.astype({"Quantity": "float", "Price": "float", "Total": "float"})
    except Exception as e:
        logger.exception("Failed to cast numeric columns")
        raise AppException(f"Type conversion error: {e}", status_code=500)

    df = df.round({"Quantity": 2, "Price": 2, "Total": 2})
    logger.debug("Clean and rename complete")
    return df


def process_pdf(input_file: str) -> Tuple[pd.DataFrame, datetime, str]:
    """
    Full pipeline: extract, normalize, clean, and return invoice table.

    Args:
        input_file (str): Path to PDF.

    Returns:
        Tuple[pd.DataFrame, datetime, str]: (clean_df, invoice_date, store_name)
    """
    logger.info(f"Processing PDF: {input_file}")
    raw = extract_raw_table(input_file)
    store, invoice_date = find_store_and_date(raw)
    rows = normalize_rows(raw)
    clean_df = clean_and_rename(rows, store, invoice_date)
    logger.info(f"Processed PDF for store {store} on {invoice_date.date()}")
    return clean_df, invoice_date, store
