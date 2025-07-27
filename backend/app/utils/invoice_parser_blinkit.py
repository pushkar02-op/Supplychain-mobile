import logging
from datetime import datetime
from typing import Tuple
import re
import pandas as pd
import pdfplumber

from app.core.exceptions import AppException

logger = logging.getLogger(__name__)


def clean_product_name(raw_name: str) -> str:
    # Remove anything after a comma (e.g., ", 500 gm")
    name = raw_name.split(",")[0]

    # Optional: remove trailing units like "400 gm" at the end
    name = re.sub(
        r"\s*\d+[\s\-]*\d*\s*(gm|kg|kilogram|ml|ltr|pcs|count|pkt|pack|bundle|box)?$",
        "",
        name,
        flags=re.IGNORECASE,
    )

    return name.strip()


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
    Removes any line that contains only 'Per'.
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
    item_lines = lines[
        header_idx : end_idx - 2
    ]  # -2 if you want to stop 2 lines before

    # Filter out lines that are exactly 'Per' or 'Qty. Unit Rate Amount'
    filtered_lines = [
        line
        for line in item_lines
        if line.strip() != "Per"
        and line.strip() != "Qty. Unit Rate Amount"
        and line.strip()
        != "Product No Product Name HSN Qty. Ord. Qty. Del. GRN Qty. UoM Amount"
    ]

    # # Print the item lines for inspection
    # print("\n--- Item lines preview ---")
    # for i, line in enumerate(filtered_lines):
    #     print(f"{i}: {line}")
    # print("--- End of item lines preview ---\n")

    return filtered_lines


def is_code_line(line):
    """
    Returns True if line starts with a 6-digit item code.
    """
    return bool(re.match(r"^\s*\d{6}\b.*\b\d{8}\b", line))


def group_raw_items(lines: list[str]) -> list[list[str]]:
    """
    Groups Blinkit items in two patterns:
     - Pattern 1: code-first → only the code line is the group.
     - Pattern 2: name-first → [name line, code line, optional detail line].
    """
    grouped = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i].strip()

        # If this is a code-first line (Pattern 1):
        if is_code_line(line):
            # Pattern 1: stand-alone code line
            grouped.append([line])
            i += 1
            continue

        # If name-first: next line must be code (Pattern 2)
        if i + 1 < n and is_code_line(lines[i + 1].strip()):
            name = line
            code = lines[i + 1].strip()
            group = [name, code]
            i += 2

            # Optional 3rd line of details
            if i < n and not is_code_line(lines[i].strip()):
                detail = lines[i].strip()
                group.append(detail)
                i += 1

            grouped.append(group)
            continue

        # Otherwise skip
        i += 1

    return grouped


def parse_grouped_items(
    grouped: list[list[str]], store: str, invoice_date: datetime
) -> pd.DataFrame:
    """
    From grouped lines, extract:
      - ItemCode, HSN, Quantity, UOM, Price, Amount, ProductName, StoreName, Date
    """
    records = []
    for group in grouped:
        # Determine pattern
        # Pattern1: group[0] is code-line
        # Pattern2: group[0] is name, group[1] is code-line, group[2] optional detail
        if is_code_line(group[0]):
            code_line = group[0]
            # name lives in the code_line itself
            name_tokens = code_line.split()
            # find HSN index
            hsn_idx = next(
                i for i, t in enumerate(name_tokens) if re.fullmatch(r"\d{8}", t)
            )
            product_name = " ".join(name_tokens[1:hsn_idx])
        else:
            # name‑first pattern
            product_name = group[0]
            if len(group) > 2:
                # append detail line
                product_name += " " + group[2]
            code_line = group[1]

        product_name = clean_product_name(product_name)

        # parse the code_line tokens
        tokens = code_line.split()
        item_code = tokens[0]
        # HSN code
        hsn_idx = next(i for i, t in enumerate(tokens) if re.fullmatch(r"\d{8}", t))
        hsn_code = tokens[hsn_idx]

        # quantities: the 4th number after HSN is the GRN Qty
        # tokens[hsn_idx+1] = OrdQty, +2=Del, +3=GRN, +4=dummy
        quantity = float(tokens[hsn_idx + 3])

        # price is tokens[hsn_idx+5]
        price = float(tokens[hsn_idx + 5])

        # UoM is the next token
        uom = tokens[hsn_idx + 6]

        # amount is always the last token
        amount = float(tokens[-1])

        records.append(
            {
                "StoreName": store,
                "Date": invoice_date,
                "ITEM_CODE": item_code,
                "HSN_CODE": hsn_code,
                "Item": product_name,
                "Quantity": quantity,
                "UOM": uom,
                "Price": price,
                "Total": amount,
            }
        )

    return pd.DataFrame(records)


def process_pdf_blinkit(input_file: str) -> Tuple[pd.DataFrame, datetime, str]:
    logger.info(f"Processing Blinkit PDF: {input_file}")
    lines = extract_raw_text_lines(input_file)

    # Now, pass these lines to your new parsing functions:
    store, invoice_date = find_store_and_date_from_lines(lines)
    item_lines = normalize_rows_from_lines(lines)

    grouped = group_raw_items(item_lines)
    print("\n=== Item Lines ===")
    for i, line in enumerate(grouped, 1):
        print(f"{i}: {line}")

    clean_df = parse_grouped_items(grouped, store, invoice_date)
    print("\n=== Parsed Invoice Items ===")
    print(clean_df.to_string(index=False))

    # Or, if you prefer logging:
    logger.info(f"\nParsed Invoice Items:\n{clean_df.to_string(index=False)}")

    logger.info(f"Processed Blinkit PDF for store {store} on {invoice_date.date()}")

    return clean_df, invoice_date, store
