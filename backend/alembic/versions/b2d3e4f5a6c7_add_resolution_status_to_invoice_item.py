"""add resolution_status to invoice_item

Revision ID: b2d3e4f5a6c7
Revises: a1c2e3f4b5d6
Create Date: 2026-03-19
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "b2d3e4f5a6c7"
down_revision = "a1c2e3f4b5d6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "invoice_item",
        sa.Column(
            "resolution_status",
            sa.String(),
            nullable=False,
            server_default="UNRESOLVED",
        ),
    )
    op.create_index(
        "ix_invoice_item_resolution_status",
        "invoice_item",
        ["resolution_status"],
    )


def downgrade() -> None:
    op.drop_index("ix_invoice_item_resolution_status", table_name="invoice_item")
    op.drop_column("invoice_item", "resolution_status")
