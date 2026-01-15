"""add_phase_9_forecasting_tables

Revision ID: 8a2f3c4d5e6f
Revises: 5c3d238e8515
Create Date: 2026-01-15 14:25:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "8a2f3c4d5e6f"
down_revision: Union[str, None] = "5c3d238e8515"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create item_burn_rate table
    op.create_table(
        "item_burn_rate",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("avg_daily_outflow_7d", sa.Float(), default=0.0),
        sa.Column("avg_daily_outflow_14d", sa.Float(), default=0.0),
        sa.Column("avg_daily_outflow_30d", sa.Float(), default=0.0),
        sa.Column("calculated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["item_id"], ["item.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("item_id"),
    )
    op.create_index(
        op.f("ix_item_burn_rate_id"), "item_burn_rate", ["id"], unique=False
    )

    # Create stock_depletion_forecast table
    op.create_table(
        "stock_depletion_forecast",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("current_ledger_qty", sa.Float(), default=0.0),
        sa.Column("avg_daily_outflow", sa.Float(), default=0.0),
        sa.Column("days_to_zero", sa.Float(), nullable=True),
        sa.Column("projected_stockout_date", sa.Date(), nullable=True),
        sa.Column("confidence_window_days", sa.Integer(), default=7),
        sa.Column("calculated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["item_id"], ["item.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("item_id"),
    )
    op.create_index(
        op.f("ix_stock_depletion_forecast_id"),
        "stock_depletion_forecast",
        ["id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        op.f("ix_stock_depletion_forecast_id"), table_name="stock_depletion_forecast"
    )
    op.drop_table("stock_depletion_forecast")
    op.drop_index(op.f("ix_item_burn_rate_id"), table_name="item_burn_rate")
    op.drop_table("item_burn_rate")
