"""add_phase_8_schema

Revision ID: 5c3d238e8515
Revises: 0369aa484df4
Create Date: 2026-01-14 19:14:17.401751

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "5c3d238e8515"
down_revision: Union[str, None] = "0369aa484df4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add processed_at column to domain_events for event relay tracking
    op.add_column(
        "domain_events",
        sa.Column("processed_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("domain_events", "processed_at")
