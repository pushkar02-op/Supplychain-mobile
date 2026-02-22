"""gb10 dual column numeric hardlock

Revision ID: c73d7eb1068e
Revises: fd618d4e594c
Create Date: 2026-02-22 14:28:39.603381

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import text

# revision identifiers, used by Alembic.
revision: str = "c73d7eb1068e"
down_revision: Union[str, None] = "fd618d4e594c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(table_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return table_name in inspector.get_table_names(schema="public")


def _column_exists(table_name: str, column_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not _table_exists(table_name):
        return False
    return any(
        col["name"] == column_name
        for col in inspector.get_columns(table_name, schema="public")
    )


def _drop_view_if_exists(view_name: str) -> None:
    op.execute(text(f'DROP VIEW IF EXISTS "{view_name}"'))


def _create_pnl_summary_view() -> None:
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
              JOIN mart m2
                ON ii.store_name = m2.name
              GROUP BY m2.id, DATE(ii.invoice_date)
            ),
            cost AS (
              SELECT
                de.mart_id,
                de.dispatch_date AS date,
                SUM(de.quantity * se.price_per_unit) AS total_cost
              FROM dispatch_entry de
              JOIN stockentry se
                ON de.batch_id = se.batch_id
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


def _migrate_to_numeric(
    table_name: str,
    column_name: str,
    numeric_type: sa.Numeric,
    scale: int,
    nullable: bool,
    server_default: str | None = None,
) -> None:
    if not _column_exists(table_name, column_name):
        return

    new_column = f"{column_name}_numeric"
    if _column_exists(table_name, new_column):
        op.drop_column(table_name, new_column)
    op.add_column(table_name, sa.Column(new_column, numeric_type, nullable=True))
    op.execute(
        text(
            f'UPDATE "{table_name}" '
            f'SET "{new_column}" = ROUND("{column_name}"::numeric, :scale)'
        ).bindparams(scale=scale)
    )

    null_count = (
        op.get_bind()
        .execute(
            text(
                f'SELECT COUNT(*) FROM "{table_name}" '
                f'WHERE "{new_column}" IS NULL AND "{column_name}" IS NOT NULL'
            )
        )
        .scalar_one()
    )
    if null_count != 0:
        raise RuntimeError(
            f"Null-cast validation failed for {table_name}.{column_name}: {null_count}"
        )

    op.drop_column(table_name, column_name)
    op.alter_column(table_name, new_column, new_column_name=column_name)
    op.alter_column(
        table_name,
        column_name,
        existing_type=numeric_type,
        nullable=nullable,
        server_default=sa.text(server_default) if server_default is not None else None,
    )


def _migrate_to_float(
    table_name: str,
    column_name: str,
    nullable: bool,
    server_default: str | None = None,
) -> None:
    if not _column_exists(table_name, column_name):
        return

    old_column = f"{column_name}_float"
    if _column_exists(table_name, old_column):
        op.drop_column(table_name, old_column)
    op.add_column(table_name, sa.Column(old_column, sa.Float(), nullable=True))
    op.execute(
        text(
            f'UPDATE "{table_name}" '
            f'SET "{old_column}" = "{column_name}"::double precision'
        )
    )

    null_count = (
        op.get_bind()
        .execute(
            text(
                f'SELECT COUNT(*) FROM "{table_name}" '
                f'WHERE "{old_column}" IS NULL AND "{column_name}" IS NOT NULL'
            )
        )
        .scalar_one()
    )
    if null_count != 0:
        raise RuntimeError(
            f"Null-cast validation failed for downgrade {table_name}.{column_name}: {null_count}"
        )

    op.drop_column(table_name, column_name)
    op.alter_column(table_name, old_column, new_column_name=column_name)
    op.alter_column(
        table_name,
        column_name,
        existing_type=sa.Float(),
        nullable=nullable,
        server_default=sa.text(server_default) if server_default is not None else None,
    )


def upgrade() -> None:
    # Drop dependent view(s) before swap.
    _drop_view_if_exists("pnl_summary")

    # Ledger-critical quantities -> NUMERIC(10,3)
    _migrate_to_numeric(
        "dispatch_entry",
        "quantity",
        sa.Numeric(10, 3),
        scale=3,
        nullable=False,
        server_default="0.000",
    )
    _migrate_to_numeric(
        "dispatch_reversal",
        "quantity",
        sa.Numeric(10, 3),
        scale=3,
        nullable=False,
        server_default="0.000",
    )
    _migrate_to_numeric(
        "order",
        "quantity_ordered",
        sa.Numeric(10, 3),
        scale=3,
        nullable=False,
        server_default="0.000",
    )
    _migrate_to_numeric(
        "order",
        "quantity_dispatched",
        sa.Numeric(10, 3),
        scale=3,
        nullable=True,
        server_default="0.000",
    )
    _migrate_to_numeric(
        "stockentry",
        "quantity",
        sa.Numeric(10, 3),
        scale=3,
        nullable=False,
        server_default="0.000",
    )
    _migrate_to_numeric(
        "invoice_item",
        "quantity",
        sa.Numeric(10, 3),
        scale=3,
        nullable=False,
        server_default="0.000",
    )

    # Financial/precision fields -> NUMERIC(18,6)
    _migrate_to_numeric(
        "stockentry",
        "price_per_unit",
        sa.Numeric(18, 6),
        scale=6,
        nullable=False,
    )
    _migrate_to_numeric(
        "stockentry",
        "total_cost",
        sa.Numeric(18, 6),
        scale=6,
        nullable=False,
    )
    _migrate_to_numeric(
        "invoice_item",
        "price",
        sa.Numeric(18, 6),
        scale=6,
        nullable=False,
    )
    _migrate_to_numeric(
        "invoice_item",
        "total",
        sa.Numeric(18, 6),
        scale=6,
        nullable=False,
    )
    _migrate_to_numeric(
        "invoice",
        "total_amount",
        sa.Numeric(18, 6),
        scale=6,
        nullable=True,
    )
    _migrate_to_numeric(
        "item_conversion_map",
        "conversion_factor",
        sa.Numeric(18, 6),
        scale=6,
        nullable=False,
    )
    _migrate_to_numeric(
        "reconciliation_mismatch",
        "confidence_score",
        sa.Numeric(18, 6),
        scale=6,
        nullable=False,
        server_default="0.000000",
    )

    _create_pnl_summary_view()


def downgrade() -> None:
    _drop_view_if_exists("pnl_summary")

    _migrate_to_float("reconciliation_mismatch", "confidence_score", nullable=False)
    _migrate_to_float("item_conversion_map", "conversion_factor", nullable=False)
    _migrate_to_float("invoice", "total_amount", nullable=True)
    _migrate_to_float("invoice_item", "total", nullable=False)
    _migrate_to_float("invoice_item", "price", nullable=False)
    _migrate_to_float("stockentry", "total_cost", nullable=False)
    _migrate_to_float("stockentry", "price_per_unit", nullable=False)

    _migrate_to_float("invoice_item", "quantity", nullable=False)
    _migrate_to_float("stockentry", "quantity", nullable=False)
    _migrate_to_float("order", "quantity_dispatched", nullable=True)
    _migrate_to_float("order", "quantity_ordered", nullable=False)
    _migrate_to_float("dispatch_reversal", "quantity", nullable=False)
    _migrate_to_float("dispatch_entry", "quantity", nullable=False)

    op.execute(text(open("app/db/views/pnl_summary_view.sql").read()))
