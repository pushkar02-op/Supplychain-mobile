"""r1.1 add warehouse_id to transactional and reconciliation models

Revision ID: a4f1e5b7c222
Revises: 9c1a7f4d2b11
Create Date: 2026-02-23 18:10:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import text

# revision identifiers, used by Alembic.
revision: str = "a4f1e5b7c222"
down_revision: Union[str, None] = "9c1a7f4d2b11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(table_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return table_name in inspector.get_table_names()


def _column_exists(table_name: str, column_name: str) -> bool:
    if not _table_exists(table_name):
        return False
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(col["name"] == column_name for col in inspector.get_columns(table_name))


def _drop_views() -> None:
    op.execute(text('DROP VIEW IF EXISTS "inventory_summary"'))
    op.execute(text('DROP VIEW IF EXISTS "inventory_signal_view"'))
    op.execute(text('DROP VIEW IF EXISTS "batch_ledger_balance_view"'))
    op.execute(text('DROP VIEW IF EXISTS "pnl_summary"'))


def _create_warehouse_views() -> None:
    op.execute(
        text(open("app/db/views/inventory_summary_view.sql", encoding="utf-8").read())
    )
    op.execute(
        text(open("app/db/views/inventory_signal_view.sql", encoding="utf-8").read())
    )
    op.execute(
        text(
            open("app/db/views/batch_ledger_balance_view.sql", encoding="utf-8").read()
        )
    )
    op.execute(text(open("app/db/views/pnl_summary_view.sql", encoding="utf-8").read()))


def _create_legacy_views() -> None:
    op.execute(
        text(
            """
            CREATE OR REPLACE VIEW inventory_summary AS
              SELECT iv.item_id,i.name,uom.code unit,
                     SUM(CASE WHEN iv.txn_type = 'IN' THEN iv.base_qty
                              WHEN iv.txn_type = 'OUT' THEN -iv.base_qty
                              ELSE 0 END) AS current_stock
              FROM inventory_txn iv
              JOIN item i ON i.id = iv.item_id
              LEFT JOIN uom ON i.default_uom_id = uom.id
              GROUP BY iv.item_id, i.name, uom.code
            """
        )
    )
    op.execute(
        text(
            """
            CREATE OR REPLACE VIEW inventory_signal_view AS
            SELECT
                item_id,
                CAST(SUM(CASE WHEN created_at >= (NOW() - INTERVAL '7 days') THEN base_qty ELSE 0 END) AS NUMERIC(10,3)) AS out_last_7d,
                CAST(SUM(CASE WHEN created_at >= (NOW() - INTERVAL '14 days')
                              AND created_at < (NOW() - INTERVAL '7 days') THEN base_qty ELSE 0 END) AS NUMERIC(10,3)) AS out_prev_7d
            FROM inventory_txn
            WHERE txn_type = 'OUT'
            GROUP BY item_id
            """
        )
    )
    op.execute(
        text(
            """
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
              GROUP BY batch_id
            """
        )
    )
    op.execute(
        text(
            """
            CREATE OR REPLACE VIEW pnl_summary AS
            WITH sales AS (
              SELECT
                m2.id AS mart_id,
                DATE(ii.invoice_date) AS date,
                SUM(ii.total) AS total_sales
              FROM invoice_item ii
              JOIN mart m2 ON ii.store_name = m2.name
              GROUP BY m2.id, DATE(ii.invoice_date)
            ),
            cost AS (
              SELECT
                de.mart_id,
                de.dispatch_date AS date,
                SUM(de.quantity * se.price_per_unit) AS total_cost
              FROM dispatch_entry de
              JOIN stockentry se ON de.batch_id = se.batch_id
              GROUP BY de.mart_id, de.dispatch_date
            )
            SELECT
              COALESCE(s.mart_id, c.mart_id) AS mart_id,
              m.name AS mart_name,
              COALESCE(s.date, c.date) AS date,
              COALESCE(s.total_sales, 0::numeric) AS total_sales,
              COALESCE(c.total_cost, 0::numeric) AS total_purchase,
              COALESCE(s.total_sales, 0::numeric) - COALESCE(c.total_cost, 0::numeric) AS profit
            FROM sales s
            FULL OUTER JOIN cost c
              ON s.mart_id = c.mart_id
              AND s.date = c.date
            LEFT JOIN mart m
              ON m.id = COALESCE(s.mart_id, c.mart_id)
            ORDER BY mart_id, date
            """
        )
    )


def _add_warehouse_column(
    table_name: str,
    fk_name: str,
    index_name: str,
    backfill_sql: str,
) -> None:
    if not _table_exists(table_name):
        return

    if not _column_exists(table_name, "warehouse_id"):
        op.add_column(
            table_name, sa.Column("warehouse_id", sa.Integer(), nullable=True)
        )

    op.execute(text(backfill_sql))

    null_count = (
        op.get_bind()
        .execute(
            text(f'SELECT COUNT(*) FROM "{table_name}" WHERE warehouse_id IS NULL')
        )
        .scalar_one()
    )
    if null_count != 0:
        raise RuntimeError(
            f"warehouse_id backfill failed for {table_name}: {null_count} null rows"
        )

    op.alter_column(table_name, "warehouse_id", nullable=False)

    inspector = sa.inspect(op.get_bind())
    existing_fks = {fk["name"] for fk in inspector.get_foreign_keys(table_name)}
    if fk_name not in existing_fks:
        op.create_foreign_key(
            fk_name, table_name, "warehouse", ["warehouse_id"], ["id"]
        )

    existing_indexes = {idx["name"] for idx in inspector.get_indexes(table_name)}
    if index_name not in existing_indexes:
        op.create_index(index_name, table_name, ["warehouse_id"], unique=False)


def upgrade() -> None:
    _drop_views()

    _add_warehouse_column(
        "batch",
        "fk_batch_warehouse_id",
        "ix_batch_warehouse_id",
        """
        UPDATE batch
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "stockentry",
        "fk_stockentry_warehouse_id",
        "ix_stockentry_warehouse_id",
        """
        UPDATE stockentry
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "dispatch_entry",
        "fk_dispatch_entry_warehouse_id",
        "ix_dispatch_entry_warehouse_id",
        """
        UPDATE dispatch_entry
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "rejection_entries",
        "fk_rejection_entries_warehouse_id",
        "ix_rejection_entries_warehouse_id",
        """
        UPDATE rejection_entries
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "order",
        "fk_order_warehouse_id",
        "ix_order_warehouse_id",
        """
        UPDATE "order"
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "invoice",
        "fk_invoice_warehouse_id",
        "ix_invoice_warehouse_id",
        """
        UPDATE invoice
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "invoice_item",
        "fk_invoice_item_warehouse_id",
        "ix_invoice_item_warehouse_id",
        """
        UPDATE invoice_item ii
        SET warehouse_id = inv.warehouse_id
        FROM invoice inv
        WHERE ii.invoice_id = inv.id
          AND ii.warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "inventory_txn",
        "fk_inventory_txn_warehouse_id",
        "ix_inventory_txn_warehouse_id",
        """
        UPDATE inventory_txn
        SET warehouse_id = (SELECT id FROM warehouse WHERE code = 'MAIN' LIMIT 1)
        WHERE warehouse_id IS NULL
        """,
    )
    _add_warehouse_column(
        "reconciliation_record",
        "fk_reconciliation_record_warehouse_id",
        "ix_reconciliation_record_warehouse_id",
        """
        UPDATE reconciliation_record rr
        SET warehouse_id = b.warehouse_id
        FROM batch b
        WHERE rr.batch_id = b.id
          AND rr.warehouse_id IS NULL
        """,
    )

    _create_warehouse_views()


def downgrade() -> None:
    _drop_views()

    for table_name, fk_name, index_name in [
        (
            "reconciliation_record",
            "fk_reconciliation_record_warehouse_id",
            "ix_reconciliation_record_warehouse_id",
        ),
        (
            "inventory_txn",
            "fk_inventory_txn_warehouse_id",
            "ix_inventory_txn_warehouse_id",
        ),
        (
            "invoice_item",
            "fk_invoice_item_warehouse_id",
            "ix_invoice_item_warehouse_id",
        ),
        ("invoice", "fk_invoice_warehouse_id", "ix_invoice_warehouse_id"),
        ("order", "fk_order_warehouse_id", "ix_order_warehouse_id"),
        (
            "rejection_entries",
            "fk_rejection_entries_warehouse_id",
            "ix_rejection_entries_warehouse_id",
        ),
        (
            "dispatch_entry",
            "fk_dispatch_entry_warehouse_id",
            "ix_dispatch_entry_warehouse_id",
        ),
        ("stockentry", "fk_stockentry_warehouse_id", "ix_stockentry_warehouse_id"),
        ("batch", "fk_batch_warehouse_id", "ix_batch_warehouse_id"),
    ]:
        if _table_exists(table_name) and _column_exists(table_name, "warehouse_id"):
            inspector = sa.inspect(op.get_bind())
            existing_indexes = {
                idx["name"] for idx in inspector.get_indexes(table_name)
            }
            if index_name in existing_indexes:
                op.drop_index(index_name, table_name=table_name)
            existing_fks = {fk["name"] for fk in inspector.get_foreign_keys(table_name)}
            if fk_name in existing_fks:
                op.drop_constraint(fk_name, table_name, type_="foreignkey")
            op.drop_column(table_name, "warehouse_id")

    _create_legacy_views()
