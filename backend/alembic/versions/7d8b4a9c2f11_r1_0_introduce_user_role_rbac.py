"""r1.0 introduce user role rbac

Revision ID: 7d8b4a9c2f11
Revises: c73d7eb1068e
Create Date: 2026-02-23 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "7d8b4a9c2f11"
down_revision: Union[str, None] = "c73d7eb1068e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "user",
        sa.Column(
            "role",
            sa.String(length=16),
            nullable=True,
            server_default="WORKER",
        ),
    )
    op.execute(
        """
        UPDATE "user"
        SET role = CASE
            WHEN is_admin = true THEN 'OWNER'
            ELSE 'WORKER'
        END
        """
    )
    op.alter_column("user", "role", existing_type=sa.String(length=16), nullable=False)
    op.create_check_constraint(
        "ck_user_role_valid",
        "user",
        "role IN ('OWNER','MANAGER','WORKER')",
    )
    op.alter_column(
        "user",
        "role",
        existing_type=sa.String(length=16),
        server_default=None,
    )
    op.drop_column("user", "is_admin")


def downgrade() -> None:
    op.add_column(
        "user",
        sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.execute(
        """
        UPDATE "user"
        SET is_admin = CASE
            WHEN role = 'OWNER' THEN true
            ELSE false
        END
        """
    )
    op.alter_column(
        "user",
        "is_admin",
        existing_type=sa.Boolean(),
        server_default=None,
    )
    op.drop_constraint("ck_user_role_valid", "user", type_="check")
    op.drop_column("user", "role")
