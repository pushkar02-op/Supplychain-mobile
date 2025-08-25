# app/db/seed/uom_seed.py

import logging
import os
from datetime import datetime

import pandas as pd
from app.db.models.uom import UOM
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def seed_uoms(db: Session, created_by: str = "system") -> None:
    # Define path to Excel file
    base_dir = os.path.dirname(__file__)
    excel_path = os.path.join(base_dir, "data/uom.xlsx")

    # Read Excel file
    try:
        df = pd.read_excel(excel_path, engine="openpyxl")
    except Exception as e:
        logger.error(f"Error reading Excel file: {e}")
        return

    # Normalize column names
    df.columns = [col.strip().lower() for col in df.columns]

    # Check required columns
    required_columns = {"code", "description"}
    if not required_columns.issubset(df.columns):
        logger.error(
            f"Missing required columns in Excel file. Required: {required_columns}"
        )
        return

    for _, row in df.iterrows():
        code = str(row["code"]).strip()
        description = str(row["description"]).strip()

        exists = (
            db.query(UOM)
            .filter(func.lower(func.trim(UOM.code)) == code.lower())
            .first()
        )

        if not exists:
            db.add(
                UOM(
                    code=code,
                    description=description,
                    created_by=created_by,
                    updated_by=created_by,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
            )

    db.commit()
    logger.info("UOM seeding complete.")
