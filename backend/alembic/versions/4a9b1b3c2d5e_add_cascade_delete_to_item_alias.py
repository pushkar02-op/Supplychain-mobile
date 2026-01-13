"""add cascade delete to item alias

Revision ID: 4a9b1b3c2d5e
Revises: 29a44a6ff2c4
Create Date: 2025-07-29 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "4a9b1b3c2d5e"
down_revision: Union[str, None] = "29a44a6ff2c4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Adds ON DELETE CASCADE to the foreign key from item_alias to item."""
    # The constraint name is taken from your error log.
    op.drop_constraint(
        "item_alias_master_item_id_fkey", "item_alias", type_="foreignkey"
    )
    op.create_foreign_key(
        "item_alias_master_item_id_fkey",  # Constraint name
        "item_alias",  # Source table
        "item",  # Target table
        ["master_item_id"],  # Source columns
        ["id"],  # Target columns
        ondelete="CASCADE",
    )


def downgrade() -> None:
    """Removes ON DELETE CASCADE from the foreign key."""
    op.drop_constraint(
        "item_alias_master_item_id_fkey", "item_alias", type_="foreignkey"
    )
    op.create_foreign_key(
        "item_alias_master_item_id_fkey",
        "item_alias",
        "item",
        ["master_item_id"],
        ["id"],
    )
