"""add_phase6_read_models

Revision ID: 0b772cd26800
Revises: 62648cac2af2
Create Date: 2026-01-14 07:40:19.312920

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0b772cd26800"
down_revision: Union[str, None] = "62648cac2af2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(open("app/db/views/batch_ledger_balance_view.sql").read())
    op.execute(open("app/db/views/inventory_signal_view.sql").read())


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DROP VIEW IF EXISTS inventory_signal_view")
    op.execute("DROP VIEW IF EXISTS batch_ledger_balance_view")
