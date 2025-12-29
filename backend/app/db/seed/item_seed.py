# app/db/seed/item_seed.py

import logging
import os
from datetime import datetime

import pandas as pd
from app.db.models.item import Item
from app.db.models.uom import UOM
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def seed_items(db: Session, created_by: str = "system") -> None:
    # Define path to Excel file
    base_dir = os.path.dirname(__file__)
    # Construct a relative path to the 'data' subdirectory
    excel_path = os.path.join(base_dir, "data", "item.xlsx")

    # Read Excel file
    try:
        df = pd.read_excel(excel_path, engine="openpyxl")
    except Exception as e:
        logger.error(f"Failed to read Excel file: {e}")
        return

    # Normalize column names
    df.columns = [col.strip().lower() for col in df.columns]

    # Expected columns: name, item_code, default_uom
    required_columns = {"name", "item_code", "default_uom"}
    if not required_columns.issubset(df.columns):
        logger.error(
            f"Missing required columns in Excel file. Required: {required_columns}"
        )
        return

    for _, row in df.iterrows():
        name = str(row["name"]).strip()

        item_code = row["item_code"]
        if pd.isna(item_code):
            item_code = None
        else:
            item_code = str(item_code).strip()
            # Handle string 'nan' manually just in case
            if item_code.lower() == "nan":
                item_code = None

        default_uom = str(row["default_uom"]).strip()

        uom = (
            db.query(UOM)
            .filter(func.lower(func.trim(UOM.code)) == default_uom.lower())
            .first()
        )
        if not uom:
            logger.warning(f"Skipping item '{name}' — UOM '{default_uom}' not found.")
            continue

        exists = (
            db.query(Item)
            .filter(func.lower(func.trim(Item.name)) == name.lower())
            .first()
        )
        if not exists:
            db.add(
                Item(
                    name=name,
                    default_uom_id=uom.id,
                    item_code=item_code,
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )

    db.commit()
    logger.info("Item seeding complete.")
