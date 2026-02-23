"""r1.1 introduce warehouse core tables

Revision ID: 9c1a7f4d2b11
Revises: 7d8b4a9c2f11
Create Date: 2026-02-23 16:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "9c1a7f4d2b11"
down_revision: Union[str, None] = "7d8b4a9c2f11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "warehouse",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.PrimaryKeyConstraint("id", name="pk_warehouse"),
        sa.UniqueConstraint("name", name="uq_warehouse_name"),
        sa.UniqueConstraint("code", name="uq_warehouse_code"),
    )
    op.create_index(op.f("ix_warehouse_id"), "warehouse", ["id"], unique=False)

    op.create_table(
        "user_warehouse_access",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("warehouse_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["user.id"], ondelete="CASCADE", name="fk_uwa_user_id"
        ),
        sa.ForeignKeyConstraint(
            ["warehouse_id"],
            ["warehouse.id"],
            ondelete="CASCADE",
            name="fk_uwa_warehouse_id",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_user_warehouse_access"),
        sa.UniqueConstraint(
            "user_id",
            "warehouse_id",
            name="uq_user_warehouse_access_user_warehouse",
        ),
    )
    op.create_index(
        op.f("ix_user_warehouse_access_id"),
        "user_warehouse_access",
        ["id"],
        unique=False,
    )

    op.execute(
        sa.text(
            """
            INSERT INTO warehouse (name, code, is_active, created_at, updated_at)
            VALUES ('Main Warehouse', 'MAIN', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """
        )
    )
    op.execute(
        sa.text(
            """
            INSERT INTO user_warehouse_access (user_id, warehouse_id, created_at)
            SELECT u.id, w.id, CURRENT_TIMESTAMP
            FROM "user" u
            JOIN warehouse w ON w.code = 'MAIN'
            """
        )
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_user_warehouse_access_id"), table_name="user_warehouse_access"
    )
    op.drop_table("user_warehouse_access")
    op.drop_index(op.f("ix_warehouse_id"), table_name="warehouse")
    op.drop_table("warehouse")
