"""r1_2 introduce daily cost tables

Revision ID: 9c581eb01843
Revises: a4f1e5b7c222
Create Date: 2026-02-24 04:55:53.466901

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "9c581eb01843"
down_revision: Union[str, None] = "a4f1e5b7c222"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "labour_cost_daily",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("warehouse_id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("total_cost", sa.Numeric(precision=18, scale=6), nullable=False),
        sa.Column("notes", sa.String(), nullable=True),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["warehouse_id"],
            ["warehouse.id"],
            name="fk_labour_cost_daily_warehouse_id",
        ),
        sa.ForeignKeyConstraint(
            ["created_by"],
            ["user.id"],
            name="fk_labour_cost_daily_created_by",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_labour_cost_daily")),
        sa.UniqueConstraint(
            "warehouse_id",
            "date",
            name="uq_labour_cost_daily_warehouse_date",
        ),
    )
    op.create_index(
        "ix_labour_cost_daily_warehouse_id",
        "labour_cost_daily",
        ["warehouse_id"],
        unique=False,
    )
    op.create_index(
        "ix_labour_cost_daily_date",
        "labour_cost_daily",
        ["date"],
        unique=False,
    )

    op.create_table(
        "transport_cost_daily",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("warehouse_id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("total_cost", sa.Numeric(precision=18, scale=6), nullable=False),
        sa.Column("notes", sa.String(), nullable=True),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["warehouse_id"],
            ["warehouse.id"],
            name="fk_transport_cost_daily_warehouse_id",
        ),
        sa.ForeignKeyConstraint(
            ["created_by"],
            ["user.id"],
            name="fk_transport_cost_daily_created_by",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_transport_cost_daily")),
        sa.UniqueConstraint(
            "warehouse_id",
            "date",
            name="uq_transport_cost_daily_warehouse_date",
        ),
    )
    op.create_index(
        "ix_transport_cost_daily_warehouse_id",
        "transport_cost_daily",
        ["warehouse_id"],
        unique=False,
    )
    op.create_index(
        "ix_transport_cost_daily_date",
        "transport_cost_daily",
        ["date"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_transport_cost_daily_date", table_name="transport_cost_daily")
    op.drop_index(
        "ix_transport_cost_daily_warehouse_id", table_name="transport_cost_daily"
    )
    op.drop_table("transport_cost_daily")

    op.drop_index("ix_labour_cost_daily_date", table_name="labour_cost_daily")
    op.drop_index("ix_labour_cost_daily_warehouse_id", table_name="labour_cost_daily")
    op.drop_table("labour_cost_daily")
