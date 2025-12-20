"""add created_by_id to audit mixin tables

Revision ID: f9e8d7c6b5a4
Revises: e2df360a0a1d
Create Date: 2025-12-21 02:40:00.000000

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "f9e8d7c6b5a4"
down_revision = "9e93302593ab"
branch_labels = None
depends_on = None

tables = [
    "user",
    "uom",
    "rejection_entries",
    "stockentry",
    "order",
    "mart",
    "item_conversion_map",
    "item_alias",
    "invoice_item",
    "item",
    "invoice",
    "dispatch_entry",
    "batch",
]


def upgrade():
    for table in tables:
        # Add column
        op.add_column(table, sa.Column("created_by_id", sa.Integer(), nullable=True))
        # Add foreign key to user.id
        # Naming convention: fk_<table_name>_<column_name>_<ref_table_name>
        # We need to be careful with length limits, but these should be fine.
        op.create_foreign_key(
            f"fk_{table}_created_by_user", table, "user", ["created_by_id"], ["id"]
        )


def downgrade():
    for table in tables:
        op.drop_constraint(f"fk_{table}_created_by_user", table, type_="foreignkey")
        op.drop_column(table, "created_by_id")
