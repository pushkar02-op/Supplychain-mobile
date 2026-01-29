"""add_item_status_field

Revision ID: fd618d4e594c
Revises: 33a73251b6ed
Create Date: 2026-01-29 08:42:43.250507

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "fd618d4e594c"
down_revision: Union[str, None] = "33a73251b6ed"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add status field to item table with ACTIVE default."""
    # Create the enum type first
    itemstatus_enum = sa.Enum("ACTIVE", "INACTIVE", name="itemstatus")
    itemstatus_enum.create(op.get_bind(), checkfirst=True)

    # Add column with default value for existing rows
    op.add_column(
        "item",
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "INACTIVE", name="itemstatus"),
            nullable=False,
            server_default="ACTIVE",
        ),
    )
    op.create_index(op.f("ix_item_status"), "item", ["status"], unique=False)


def downgrade() -> None:
    """Remove status field from item table."""
    op.drop_index(op.f("ix_item_status"), table_name="item")
    op.drop_column("item", "status")
    # Drop the enum type
    sa.Enum(name="itemstatus").drop(op.get_bind(), checkfirst=True)
