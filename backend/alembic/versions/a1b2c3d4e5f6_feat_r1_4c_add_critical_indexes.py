"""feat(r1-4c): add critical audit and ledger indexes

Revision ID: a1b2c3d4e5f6
Revises: f92b305d2054
Create Date: 2026-02-26 00:40:00.000000

"""

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "f92b305d2054"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        "ix_audit_log_entity_type", "audit_log", ["entity_type"], if_not_exists=True
    )
    op.create_index(
        "ix_audit_log_action_type", "audit_log", ["action_type"], if_not_exists=True
    )
    op.create_index(
        "ix_audit_log_created_at", "audit_log", ["created_at"], if_not_exists=True
    )
    op.create_index(
        "ix_inventory_txn_batch_id", "inventory_txn", ["batch_id"], if_not_exists=True
    )
    op.create_index(
        "ix_inventory_txn_item_id", "inventory_txn", ["item_id"], if_not_exists=True
    )
    op.create_index(
        "ix_inventory_txn_created_at",
        "inventory_txn",
        ["created_at"],
        if_not_exists=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_inventory_txn_created_at", table_name="inventory_txn", if_exists=True
    )
    op.drop_index(
        "ix_inventory_txn_item_id", table_name="inventory_txn", if_exists=True
    )
    op.drop_index(
        "ix_inventory_txn_batch_id", table_name="inventory_txn", if_exists=True
    )
    op.drop_index("ix_audit_log_created_at", table_name="audit_log", if_exists=True)
    op.drop_index("ix_audit_log_action_type", table_name="audit_log", if_exists=True)
    op.drop_index("ix_audit_log_entity_type", table_name="audit_log", if_exists=True)
