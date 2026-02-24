"""add_phase6_read_models

Revision ID: 0b772cd26800
Revises: 62648cac2af2
Create Date: 2026-01-14 07:40:19.312920

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0b772cd26800"
down_revision: Union[str, None] = "62648cac2af2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

LEGACY_BATCH_LEDGER_BALANCE_VIEW_SQL = """
CREATE OR REPLACE VIEW batch_ledger_balance_view AS
  SELECT
    batch_id,
    CAST(SUM(
        CASE
            WHEN txn_type IN ('IN', 'ADJUST') THEN base_qty
            WHEN txn_type IN ('OUT', 'REJECT', 'DISPATCH') THEN -base_qty
            ELSE 0
        END
    ) AS NUMERIC(10,3)) AS ledger_qty
  FROM inventory_txn
  WHERE batch_id IS NOT NULL
  GROUP BY batch_id;
"""

LEGACY_INVENTORY_SIGNAL_VIEW_SQL = """
CREATE OR REPLACE VIEW inventory_signal_view AS
SELECT
    item_id,
    CAST(SUM(CASE WHEN created_at >= (NOW() - INTERVAL '7 days') THEN base_qty ELSE 0 END) AS NUMERIC(10,3)) as out_last_7d,
    CAST(SUM(CASE WHEN created_at >= (NOW() - INTERVAL '14 days') AND created_at < (NOW() - INTERVAL '7 days') THEN base_qty ELSE 0 END) AS NUMERIC(10,3)) as out_prev_7d
FROM inventory_txn
WHERE txn_type = 'OUT'
GROUP BY item_id;
"""


def upgrade() -> None:
    """Upgrade schema."""
    # Keep this migration deterministic for fresh DB bootstrap.
    # Warehouse-aware view variants are introduced in a later revision.
    op.execute(sa.text(LEGACY_BATCH_LEDGER_BALANCE_VIEW_SQL))
    op.execute(sa.text(LEGACY_INVENTORY_SIGNAL_VIEW_SQL))


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DROP VIEW IF EXISTS inventory_signal_view")
    op.execute("DROP VIEW IF EXISTS batch_ledger_balance_view")
