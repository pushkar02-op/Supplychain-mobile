import re
import pandas as pd
import pdfplumber
from datetime import datetime

def extract_raw_table(input_file: str) -> pd.DataFrame:
    rows = []
    with pdfplumber.open(input_file) as pdf:
        for page in pdf.pages:
            tbl = page.extract_table()
            if tbl:
                rows.extend(tbl)
    return pd.DataFrame(rows)

def find_store_and_date(df: pd.DataFrame):
    for idx, row in df.iterrows():
        if "Site Name" in row.values:
            col = row[row == "Site Name"].index[0]
            store = df.iat[idx + 1, col].strip().replace(" ", "_")
            break
    date_txt = re.search(r"(\d{2}\.\d{2}\.\d{4})", df.iat[0, 2]).group(1)
    invoice_date = datetime.strptime(date_txt, "%d.%m.%Y")
    return store, invoice_date

def normalize_rows(df: pd.DataFrame) -> pd.DataFrame:
    df = df.iloc[8:].copy()
    # drop header repeats & trailing totals
    first = df[0].tolist().index("Sr.No")
    df = pd.concat([df.iloc[first:first+1], df[df[0] != "Sr.No"]]).reset_index(drop=True)
    if "Grand Total of Qty" in df[0].values:
        end = df[df[0] == "Grand Total of Qty"].index[0]
        df = df.iloc[:end]
    return df

def clean_and_rename(df: pd.DataFrame, store: str, invoice_date: datetime) -> pd.DataFrame:
    df["StoreName"] = store
    df["Date"] = invoice_date

    # drop unwanted columns by index
    df = df.drop(columns=[0, 6, 8, 9])

    # rename & clean
    df = df.iloc[1:].copy()  # remove header row
    df.columns = ["HSN_CODE","ITEM_CODE","Item","Quantity","UOM","Price","Total","Date","StoreName"]
    df["Total"] = df["Total"].str.replace(",", "")
    df["Item"] = df["Item"].str.replace(r'\n\d{2}.\d{2}.\d{4}\n\w{4}$', '', regex=True)
    df["Item"]  = df["Item"].str.strip("._/\n")
    df["HSN_CODE"] = df["HSN_CODE"].str.replace("\n","")
    df["ITEM_CODE"] = df["ITEM_CODE"].str.split("\n").str[0]

    df = df.astype({
        "Quantity":"float",
        "Price":"float",
        "Total":"float"
    })
    return df.round({"Quantity":2,"Price":2,"Total":2})

def process_pdf(input_file: str):
    raw = extract_raw_table(input_file)
    store, invoice_date = find_store_and_date(raw)
    rows = normalize_rows(raw)
    clean = clean_and_rename(rows, store, invoice_date)
    return clean, invoice_date, store
 