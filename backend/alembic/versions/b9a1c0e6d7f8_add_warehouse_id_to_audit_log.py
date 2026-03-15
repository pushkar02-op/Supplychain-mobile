"""add warehouse id to audit log

Revision ID: b9a1c0e6d7f8
Revises: a8c4d2e1b7f0
Create Date: 2026-03-14
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "b9a1c0e6d7f8"
down_revision = "a8c4d2e1b7f0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "audit_log",
        sa.Column("warehouse_id", sa.Integer(), nullable=True),
    )
    op.create_index(
        "ix_audit_log_warehouse_id",
        "audit_log",
        ["warehouse_id"],
    )
    op.execute(
        """
        UPDATE audit_log
        SET warehouse_id = ("metadata"->>'warehouse_id')::integer
        WHERE warehouse_id IS NULL
 AND ("metadata"->>'warehouse_id') IS NOT NULL
"""
    )
    op.create_index(
        "ix_audit_log_warehouse_created_at",
        "audit_log",
        ["warehouse_id", sa.text("created_at DESC")],
    )


def downgrade() -> None:
    op.drop_index("ix_audit_log_warehouse_created_at", table_name="audit_log")
    op.drop_index("ix_audit_log_warehouse_id", table_name="audit_log")
    op.drop_column("audit_log", "warehouse_id")
