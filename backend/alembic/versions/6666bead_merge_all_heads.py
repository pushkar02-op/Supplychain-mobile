"""merge_all_heads

Revision ID: 6666bead_merge_all
Revises: a1b2c3d4e5f6, 44d1fc292d1b, fd618d4e594c, f9e8d7c6b5a4, a165ec055757, 0b772cd26800, 0b709fc8a19b
Create Date: 2026-03-08 02:00:00.000000

"""

from typing import Sequence, Union
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "6666bead_merge_all"
down_revision: Union[str, Sequence[str], None] = (
    "a1b2c3d4e5f6",
    "44d1fc292d1b",
    "fd618d4e594c",
    "f9e8d7c6b5a4",
    "a165ec055757",
    "0b772cd26800",
    "0b709fc8a19b",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
