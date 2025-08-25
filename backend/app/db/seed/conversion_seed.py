# app/db/seed/conversion_seed.py

import logging
import os
from datetime import datetime

import pandas as pd
from app.db.models.item import Item
from app.db.models.item_conversion_map import ItemConversionMap
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def seed_conversions(db: Session, created_by: str = "system") -> None:
    # Define path to Excel file
    base_dir = os.path.dirname(__file__)
    excel_path = os.path.join(base_dir, "data/conversion.xlsx")

    # Read Excel file
    try:
        df = pd.read_excel(excel_path, engine="openpyxl")
    except Exception as e:
        logger.error(f"Failed to read Excel file: {e}")
        return

    # Normalize column names
    df.columns = [col.strip().lower() for col in df.columns]
    required_columns = {"item_name", "source_unit", "target_unit", "factor"}
    if not required_columns.issubset(df.columns):
        logger.error(
            f"Missing required columns in Excel file. Required: {required_columns}"
        )
        return

    for _, row in df.iterrows():
        item_name = str(row["item_name"]).strip()
        source_unit = str(row["source_unit"]).strip()
        target_unit = str(row["target_unit"]).strip()
        try:
            factor = float(row["factor"])
        except (ValueError, TypeError):
            logger.warning(
                f"Invalid conversion factor for item '{item_name}'. Skipping."
            )
            continue

        item = (
            db.query(Item)
            .filter(func.lower(func.trim(Item.name)) == item_name.lower())
            .first()
        )

        if not item:
            logger.warning(f"Item not found for: {repr(item_name)}")
            continue

        exists = db.query(ItemConversionMap).filter_by(item_id=item.id).first()

        if not exists:
            db.add(
                ItemConversionMap(
                    item_id=item.id,
                    source_unit=source_unit,
                    target_unit=target_unit,
                    conversion_factor=factor,
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )

    db.commit()
    logger.info("Item conversion seeding complete.")
