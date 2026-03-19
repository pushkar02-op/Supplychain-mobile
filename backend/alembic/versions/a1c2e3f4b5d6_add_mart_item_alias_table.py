"""add_mart_item_alias_table

Revision ID: a1c2e3f4b5d6
Revises: b9a1c0e6d7f8
Create Date: 2026-03-19

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a1c2e3f4b5d6"
down_revision: Union[str, None] = "b9a1c0e6d7f8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mart_item_alias",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("mart_id", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("alias_code", sa.String(), nullable=True),
        sa.Column("alias_name", sa.String(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("created_by", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["item_id"], ["item.id"]),
        sa.ForeignKeyConstraint(["mart_id"], ["mart.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("mart_id", "alias_code", name="uq_mart_alias_code"),
        sa.UniqueConstraint("mart_id", "alias_name", name="uq_mart_alias_name"),
    )
    op.create_index(
        op.f("ix_mart_item_alias_id"), "mart_item_alias", ["id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_mart_item_alias_id"), table_name="mart_item_alias")
    op.drop_table("mart_item_alias")
