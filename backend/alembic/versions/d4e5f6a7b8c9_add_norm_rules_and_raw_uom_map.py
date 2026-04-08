"""add supplier norm rules, raw uom map, and source_bill_item_id

Revision ID: d4e5f6a7b8c9
Revises: c3e4f5a6b7d8
Create Date: 2026-03-26
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "d4e5f6a7b8c9"
down_revision = "c3e4f5a6b7d8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. supplier_item_norm_rule table
    op.create_table(
        "supplier_item_norm_rule",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("company_name", sa.String(), nullable=False, index=True),
        sa.Column("mart_id", sa.Integer(), sa.ForeignKey("mart.id"), nullable=True),
        sa.Column("item_code", sa.String(), nullable=True, index=True),
        sa.Column("item_name_stem", sa.String(), nullable=True),
        sa.Column("raw_uom", sa.String(), nullable=False),
        sa.Column("suffix_pattern", sa.String(), nullable=True),
        sa.Column(
            "target_item_id", sa.Integer(), sa.ForeignKey("item.id"), nullable=False
        ),
        sa.Column("rule_type", sa.String(), nullable=False),
        sa.Column("rule_value", sa.Numeric(18, 6), nullable=True),
        sa.Column("confirmed", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("confirmed_by", sa.Integer(), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(), nullable=True),
        sa.Column(
            "warehouse_id",
            sa.Integer(),
            sa.ForeignKey("warehouse.id"),
            nullable=False,
            index=True,
        ),
        # Audit mixin columns
        sa.Column("created_by", sa.String(), nullable=True),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("updated_by", sa.String(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(), server_default=sa.func.now(), nullable=True
        ),
        sa.Column(
            "updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=True
        ),
        sa.UniqueConstraint(
            "company_name",
            "item_code",
            "raw_uom",
            "suffix_pattern",
            "warehouse_id",
            name="uq_company_norm_rule",
        ),
    )

    # 2. raw_uom_map table
    op.create_table(
        "raw_uom_map",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("format_type", sa.String(), nullable=False),
        sa.Column("raw_uom_text", sa.String(), nullable=False),
        sa.Column("billing_hint", sa.String(), nullable=False),
        sa.UniqueConstraint("format_type", "raw_uom_text", name="uq_format_raw_uom"),
    )

    # Seed raw_uom_map with Zomato format data
    op.execute(
        """
        INSERT INTO raw_uom_map (format_type, raw_uom_text, billing_hint) VALUES
        ('zomato', 'Kilogram', 'weight'),
        ('zomato', 'Count', 'count'),
        ('zomato', 'Per piece', 'count'),
        ('zomato', 'Pack', 'composite')
        """
    )

    # 3. Add source_bill_item_id to stockentry
    #    (table name is auto-generated from class StockEntry → "stockentry")
    op.add_column(
        "stockentry",
        sa.Column(
            "source_bill_item_id",
            sa.Integer(),
            sa.ForeignKey("invoice_item.id"),
            nullable=True,
            index=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("stockentry", "source_bill_item_id")
    op.drop_table("raw_uom_map")
    op.drop_table("supplier_item_norm_rule")
