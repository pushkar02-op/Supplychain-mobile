"""add_check_constraint_batch_quantity_positive

Revision ID: 324bc2ce9291
Revises: f9e8d7c6b5a4
Create Date: 2025-12-23 18:44:18.736336

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "324bc2ce9291"
down_revision: Union[str, None] = "f9e8d7c6b5a4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        "ALTER TABLE batch ADD CONSTRAINT chk_batch_quantity_non_negative CHECK (quantity >= 0)"
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("ALTER TABLE batch DROP CONSTRAINT chk_batch_quantity_non_negative")
