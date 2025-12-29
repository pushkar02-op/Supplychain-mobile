"""add_batch_quantity_num_compatibility

Revision ID: ecf5f70c3bae
Revises: 92f85728c643
Create Date: 2025-12-23 20:05:47.741198

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "ecf5f70c3bae"
down_revision: Union[str, None] = "92f85728c643"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- BATCH ---
    # 1. Add column
    op.add_column("batch", sa.Column("quantity_num", sa.Numeric(18, 6), nullable=True))

    # 2. Backfill data
    op.execute("UPDATE batch SET quantity_num = CAST(quantity AS NUMERIC(18, 6))")

    # 3. Add constraint
    op.create_check_constraint(
        "chk_batch_quantity_num_non_negative", "batch", "quantity_num >= 0"
    )

    # --- REJECTION ENTERIES ---
    # 1. Add column
    op.add_column(
        "rejection_entries", sa.Column("quantity_num", sa.Numeric(18, 6), nullable=True)
    )

    # 2. Backfill data
    op.execute(
        "UPDATE rejection_entries SET quantity_num = CAST(quantity AS NUMERIC(18, 6))"
    )

    # 3. Add constraint (Temporary name for Stage 1)
    op.create_check_constraint(
        "chk_rejection_entry_quantity_num_non_negative",
        "rejection_entries",
        "quantity_num >= 0",
    )


def downgrade() -> None:
    # --- REJECTION ENTERIES ---
    op.drop_constraint(
        "chk_rejection_entry_quantity_num_non_negative",
        "rejection_entries",
        type_="check",
    )
    op.drop_column("rejection_entries", "quantity_num")

    # --- BATCH ---
    op.drop_constraint("chk_batch_quantity_num_non_negative", "batch", type_="check")
    op.drop_column("batch", "quantity_num")
