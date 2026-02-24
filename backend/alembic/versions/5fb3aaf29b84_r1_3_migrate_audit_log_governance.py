"""r1_3_migrate_audit_log_governance

Revision ID: 5fb3aaf29b84
Revises: 9c581eb01843
Create Date: 2026-02-24 23:58:18.161746

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "5fb3aaf29b84"
down_revision: Union[str, None] = "9c581eb01843"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    with op.batch_alter_table("audit_log", schema=None) as batch_op:
        batch_op.add_column(sa.Column("metadata", sa.JSON(), nullable=True))
        batch_op.alter_column(
            "user_id",
            existing_type=sa.Integer(),
            new_column_name="actor_user_id",
            existing_nullable=False,
        )
        batch_op.alter_column(
            "table_name",
            existing_type=sa.String(),
            new_column_name="entity_type",
            existing_nullable=False,
        )
        batch_op.alter_column(
            "record_id",
            existing_type=sa.Integer(),
            new_column_name="entity_id",
            existing_nullable=False,
            nullable=True,
        )
        batch_op.alter_column(
            "timestamp",
            existing_type=sa.DateTime(),
            new_column_name="created_at",
            existing_nullable=True,
            nullable=False,
        )

    if dialect == "postgresql":
        op.execute(
            """
            UPDATE audit_log
            SET metadata = jsonb_build_object('legacy_changes', changes)
            WHERE changes IS NOT NULL AND btrim(changes) <> ''
            """
        )
    elif dialect == "sqlite":
        op.execute(
            """
            UPDATE audit_log
            SET metadata = json_object('legacy_changes', changes)
            WHERE changes IS NOT NULL AND trim(changes) <> ''
            """
        )
    else:
        op.execute(
            """
            UPDATE audit_log
            SET metadata = NULL
            WHERE metadata IS NULL
            """
        )

    with op.batch_alter_table("audit_log", schema=None) as batch_op:
        batch_op.drop_column("changes")
        batch_op.create_foreign_key(
            "fk_audit_log_actor_user_id_user",
            "user",
            ["actor_user_id"],
            ["id"],
        )

    op.create_index(
        "ix_audit_log_created_at",
        "audit_log",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_audit_log_actor_user_id",
        "audit_log",
        ["actor_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_audit_log_entity_type",
        "audit_log",
        ["entity_type"],
        unique=False,
    )


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    op.drop_index("ix_audit_log_entity_type", table_name="audit_log")
    op.drop_index("ix_audit_log_actor_user_id", table_name="audit_log")
    op.drop_index("ix_audit_log_created_at", table_name="audit_log")

    with op.batch_alter_table("audit_log", schema=None) as batch_op:
        batch_op.drop_constraint(
            "fk_audit_log_actor_user_id_user",
            type_="foreignkey",
        )
        batch_op.add_column(sa.Column("changes", sa.Text(), nullable=True))

    if dialect == "postgresql":
        op.execute(
            """
            UPDATE audit_log
            SET changes = metadata->>'legacy_changes'
            WHERE metadata IS NOT NULL
            """
        )
    elif dialect == "sqlite":
        op.execute(
            """
            UPDATE audit_log
            SET changes = json_extract(metadata, '$.legacy_changes')
            WHERE metadata IS NOT NULL
            """
        )

    with op.batch_alter_table("audit_log", schema=None) as batch_op:
        batch_op.alter_column(
            "actor_user_id",
            existing_type=sa.Integer(),
            new_column_name="user_id",
            existing_nullable=False,
        )
        batch_op.alter_column(
            "entity_type",
            existing_type=sa.String(),
            new_column_name="table_name",
            existing_nullable=False,
        )
        batch_op.alter_column(
            "entity_id",
            existing_type=sa.Integer(),
            new_column_name="record_id",
            existing_nullable=True,
            nullable=False,
        )
        batch_op.alter_column(
            "created_at",
            existing_type=sa.DateTime(),
            new_column_name="timestamp",
            existing_nullable=False,
            nullable=True,
        )
        batch_op.drop_column("metadata")
