"""add is_active to mart and uom

Revision ID: a8c4d2e1b7f0
Revises: 5eedadffa5de
Create Date: 2026-03-10 22:10:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a8c4d2e1b7f0"
down_revision = "5eedadffa5de"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "mart",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        "uom",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.alter_column("mart", "is_active", server_default=None)
    op.alter_column("uom", "is_active", server_default=None)


def downgrade() -> None:
    op.drop_column("uom", "is_active")
    op.drop_column("mart", "is_active")
