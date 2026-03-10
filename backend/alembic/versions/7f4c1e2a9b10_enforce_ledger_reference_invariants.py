"""enforce ledger reference invariants

Revision ID: 7f4c1e2a9b10
Revises: 6666bead_merge_all
Create Date: 2026-03-10 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "7f4c1e2a9b10"
down_revision: Union[str, Sequence[str], None] = "6666bead_merge_all"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        UPDATE inventory_txn AS t
        SET ref_id = d.id
        FROM dispatch_entry AS d
        WHERE t.ref_type = 'dispatch_entry'
          AND t.ref_id IS NULL
          AND t.batch_id IS NOT NULL
          AND d.batch_id = t.batch_id
          AND d.item_id = t.item_id
          AND d.created_at <= t.created_at
          AND d.id = (
              SELECT d2.id
              FROM dispatch_entry AS d2
              WHERE d2.batch_id = t.batch_id
                AND d2.item_id = t.item_id
                AND d2.created_at <= t.created_at
              ORDER BY d2.created_at DESC, d2.id DESC
              LIMIT 1
          )
        """
    )
    op.execute(
        """
        UPDATE inventory_txn
        SET ref_type = COALESCE(ref_type, 'manual'),
            ref_id = COALESCE(ref_id, id)
        WHERE ref_type IS NULL
           OR ref_id IS NULL
        """
    )
    op.alter_column(
        "inventory_txn",
        "ref_type",
        existing_type=sa.String(length=32),
        nullable=False,
    )
    op.alter_column(
        "inventory_txn",
        "ref_id",
        existing_type=sa.Integer(),
        nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "inventory_txn",
        "ref_type",
        existing_type=sa.String(length=32),
        nullable=True,
    )
    op.alter_column(
        "inventory_txn",
        "ref_id",
        existing_type=sa.Integer(),
        nullable=True,
    )
