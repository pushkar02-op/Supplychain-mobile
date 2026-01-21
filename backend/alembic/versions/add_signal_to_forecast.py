"""Add signal column to stock_depletion_forecast

Revision ID: add_signal_to_forecast
Revises:
Create Date: 2026-01-18
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "add_signal_to_forecast"
down_revision = "8a2f3c4d5e6f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add signal column to stock_depletion_forecast
    # Add signal column to stock_depletion_forecast if it doesn't exist
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c["name"] for c in inspector.get_columns("stock_depletion_forecast")]
    if "signal" not in columns:
        op.add_column(
            "stock_depletion_forecast",
            sa.Column("signal", sa.String(20), server_default="STABLE", nullable=True),
        )


def downgrade() -> None:
    op.drop_column("stock_depletion_forecast", "signal")
