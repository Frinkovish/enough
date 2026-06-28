"""create craving_sessions table

Revision ID: 0001
Revises:
Create Date: 2026-06-27

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "craving_sessions",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False, server_default="1200"),
        sa.Column("suggested_task_id", sa.String(length=64), nullable=False),
        sa.Column("outcome", sa.String(length=32), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
    )
    op.create_index("ix_craving_sessions_user_id", "craving_sessions", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_craving_sessions_user_id", table_name="craving_sessions")
    op.drop_table("craving_sessions")
