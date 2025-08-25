# app/db/seed/uom_seed.py

import logging
import os
from datetime import datetime

import pandas as pd
from app.db.models.item import Item
from app.db.models.item_alias import ItemAlias
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def seed_aliases(db: Session, created_by: str = "system") -> None:
    # Define path to Excel file
    base_dir = os.path.dirname(__file__)
    excel_path = os.path.join(base_dir, "data/alias.xlsx")

    # Read Excel file
    try:
        df = pd.read_excel(excel_path, engine="openpyxl")
    except Exception as e:
        logger.error(f"Failed to read Excel file: {e}")
        return

    # Normalize column names
    df.columns = [col.strip().lower() for col in df.columns]

    # Required columns
    required_columns = {"item_name", "alias_name", "alias_code"}
    if not required_columns.issubset(df.columns):
        logger.error(
            f"Missing required columns in Excel file. Required: {required_columns}"
        )
        return

    for _, row in df.iterrows():
        item_name = str(row["item_name"]).strip()
        alias_name = str(row["alias_name"]).strip()
        alias_code = str(row["alias_code"]).strip()

        item = (
            db.query(Item)
            .filter(func.lower(func.trim(Item.name)) == item_name.lower())
            .first()
        )

        if not item:
            logger.warning(
                f"Skipping alias '{alias_name}' — item '{item_name}' not found."
            )
            continue

        alias_exists = (
            db.query(ItemAlias)
            .filter(
                func.lower(func.trim(ItemAlias.alias_name)) == alias_name.lower(),
                ItemAlias.master_item_id == item.id,
            )
            .first()
        )

        if not alias_exists:
            db.add(
                ItemAlias(
                    master_item_id=item.id,
                    alias_name=alias_name,
                    alias_code=alias_code,
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )

    db.commit()
    logger.info("Item alias seeding complete.")
