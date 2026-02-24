"""feat(r1-4): add financial_lock_date to warehouse

Revision ID: f92b305d2054
Revises: 5fb3aaf29b84
Create Date: 2026-02-25 01:43:12.612900

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f92b305d2054"
down_revision: Union[str, None] = "5fb3aaf29b84"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "warehouse", sa.Column("financial_lock_date", sa.Date(), nullable=True)
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("warehouse", "financial_lock_date")
