"""merge_phase9_with_rejection

Revision ID: 44d1fc292d1b
Revises: 307e24fa5f89, add_signal_to_forecast
Create Date: 2026-01-22 02:43:44.479223

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "44d1fc292d1b"
down_revision: Union[str, None] = ("307e24fa5f89", "add_signal_to_forecast")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
