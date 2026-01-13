"""swap_quantity_columns_to_numeric

Revision ID: bd09ecc8dd78
Revises: ecf5f70c3bae
Create Date: 2025-12-23 20:36:22.297378

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "bd09ecc8dd78"
down_revision: Union[str, None] = "ecf5f70c3bae"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Verify no NULLs (safety check)
    from sqlalchemy import text

    conn = op.get_bind()

    def constraint_exists(name):
        return (
            conn.execute(
                text(f"SELECT 1 FROM pg_constraint WHERE conname = '{name}'")
            ).scalar()
            is not None
        )

    batch_nulls = conn.execute(
        text("SELECT COUNT(*) FROM batch WHERE quantity_num IS NULL")
    ).scalar()
    rej_nulls = conn.execute(
        text("SELECT COUNT(*) FROM rejection_entries WHERE quantity_num IS NULL")
    ).scalar()

    if batch_nulls > 0 or rej_nulls > 0:
        raise Exception(
            f"ABORT: Found NULLs in quantity_num (batch: {batch_nulls}, rejection_entries: {rej_nulls})"
        )

    # --- BATCH TABLE ---
    # 1. Drop old constraint
    if constraint_exists("chk_batch_quantity_non_negative"):
        op.drop_constraint("chk_batch_quantity_non_negative", "batch", type_="check")

    # 2. Drop old INTEGER column
    op.drop_column("batch", "quantity")

    # 3. Rename quantity_num -> quantity
    op.alter_column("batch", "quantity_num", new_column_name="quantity")

    # 4. Rename constraint to canonical name
    if constraint_exists("chk_batch_quantity_num_non_negative"):
        op.drop_constraint(
            "chk_batch_quantity_num_non_negative", "batch", type_="check"
        )
    op.create_check_constraint(
        "chk_batch_quantity_non_negative", "batch", "quantity >= 0"
    )

    # --- REJECTION_ENTRIES TABLE ---
    # 1. Drop old constraint
    if constraint_exists("chk_rejection_entries_quantity_non_negative"):
        op.drop_constraint(
            "chk_rejection_entries_quantity_non_negative",
            "rejection_entries",
            type_="check",
        )

    # 2. Drop old INTEGER column
    op.drop_column("rejection_entries", "quantity")

    # 3. Rename quantity_num -> quantity
    op.alter_column("rejection_entries", "quantity_num", new_column_name="quantity")

    # 4. Rename constraint to canonical name
    if constraint_exists("chk_rejection_entry_quantity_num_non_negative"):
        op.drop_constraint(
            "chk_rejection_entry_quantity_num_non_negative",
            "rejection_entries",
            type_="check",
        )
    op.create_check_constraint(
        "chk_rejection_entries_quantity_non_negative",
        "rejection_entries",
        "quantity >= 0",
    )


def downgrade() -> None:
    # --- REJECTION_ENTRIES TABLE (reverse order) ---
    # 1. Drop new constraint
    op.drop_constraint(
        "chk_rejection_entries_quantity_non_negative",
        "rejection_entries",
        type_="check",
    )

    # 2. Rename quantity -> quantity_num
    op.alter_column("rejection_entries", "quantity", new_column_name="quantity_num")

    # 3. Add back INTEGER column
    op.add_column(
        "rejection_entries",
        sa.Column("quantity", sa.Integer(), nullable=False, server_default="0"),
    )
    op.execute("UPDATE rejection_entries SET quantity = CAST(quantity_num AS INTEGER)")
    op.alter_column("rejection_entries", "quantity", server_default=None)

    # 4. Restore old constraints
    op.create_check_constraint(
        "chk_rejection_entries_quantity_non_negative",
        "rejection_entries",
        "quantity >= 0",
    )
    op.create_check_constraint(
        "chk_rejection_entry_quantity_num_non_negative",
        "rejection_entries",
        "quantity_num >= 0",
    )

    # --- BATCH TABLE (reverse order) ---
    # 1. Drop new constraint
    op.drop_constraint("chk_batch_quantity_non_negative", "batch", type_="check")

    # 2. Rename quantity -> quantity_num
    op.alter_column("batch", "quantity", new_column_name="quantity_num")

    # 3. Add back INTEGER column
    op.add_column(
        "batch", sa.Column("quantity", sa.Integer(), nullable=False, server_default="0")
    )
    op.execute("UPDATE batch SET quantity = CAST(quantity_num AS INTEGER)")
    op.alter_column("batch", "quantity", server_default=None)

    # 4. Restore old constraints
    op.create_check_constraint(
        "chk_batch_quantity_non_negative", "batch", "quantity >= 0"
    )
    op.create_check_constraint(
        "chk_batch_quantity_num_non_negative", "batch", "quantity_num >= 0"
    )
