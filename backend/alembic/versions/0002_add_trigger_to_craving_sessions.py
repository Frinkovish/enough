"""add trigger to craving_sessions

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-28

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("craving_sessions") as batch_op:
        batch_op.add_column(
            sa.Column("trigger", sa.String(length=32), nullable=False, server_default="other"),
        )
        batch_op.alter_column("trigger", server_default=None)


def downgrade() -> None:
    with op.batch_alter_table("craving_sessions") as batch_op:
        batch_op.drop_column("trigger")
