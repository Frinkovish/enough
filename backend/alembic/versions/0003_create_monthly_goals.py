"""create monthly_goals table

Revision ID: 0003
Revises: 0002
Create Date: 2026-06-28

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "monthly_goals",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("month", sa.Date(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "month", name="uq_monthly_goals_user_month"),
    )
    op.create_index("ix_monthly_goals_user_id", "monthly_goals", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_monthly_goals_user_id", table_name="monthly_goals")
    op.drop_table("monthly_goals")
