"""create reconciliation_record table

Revision ID: 5eedadffa5de
Revises: 7f4c1e2a9b10
Create Date: 2026-03-10 09:31:07.387367

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "5eedadffa5de"
down_revision: Union[str, None] = "7f4c1e2a9b10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "reconciliation_record",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("batch_id", sa.Integer(), nullable=False),
        sa.Column("warehouse_id", sa.Integer(), nullable=False),
        sa.Column("observed_ledger_qty", sa.Numeric(10, 3), nullable=False),
        sa.Column("observed_state_qty", sa.Numeric(10, 3), nullable=False),
        sa.Column("drift_amount", sa.Numeric(10, 3), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("detected_at", sa.DateTime(), nullable=True),
        sa.Column("resolution_txn_id", sa.Integer(), nullable=True),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.Column("resolved_by", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["batch_id"], ["batch.id"]),
        sa.ForeignKeyConstraint(["resolution_txn_id"], ["inventory_txn.id"]),
        sa.ForeignKeyConstraint(["warehouse_id"], ["warehouse.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_reconciliation_record_id"),
        "reconciliation_record",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_reconciliation_record_warehouse_id"),
        "reconciliation_record",
        ["warehouse_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        op.f("ix_reconciliation_record_warehouse_id"),
        table_name="reconciliation_record",
    )
    op.drop_index(
        op.f("ix_reconciliation_record_id"),
        table_name="reconciliation_record",
    )
    op.drop_table("reconciliation_record")
