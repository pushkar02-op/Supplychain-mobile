"""add_creation_intent_to_item

Revision ID: 33a73251b6ed
Revises: 44d1fc292d1b
Create Date: 2026-01-28 00:20:00.859869

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "33a73251b6ed"
down_revision: Union[str, None] = "44d1fc292d1b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("item", sa.Column("creation_intent", sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("item", "creation_intent")
