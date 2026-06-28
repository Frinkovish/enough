"""add target/unit/progress to monthly_goals, drop one-per-month
limit, link craving_sessions to a goal

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-28

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("monthly_goals") as batch_op:
        batch_op.drop_constraint("uq_monthly_goals_user_month", type_="unique")
        batch_op.add_column(sa.Column("target", sa.Integer(), nullable=False, server_default="1"))
        batch_op.add_column(
            sa.Column("unit", sa.String(length=32), nullable=False, server_default="times")
        )
        batch_op.add_column(sa.Column("progress", sa.Integer(), nullable=False, server_default="0"))
        batch_op.alter_column("target", server_default=None)
        batch_op.alter_column("unit", server_default=None)
        batch_op.alter_column("progress", server_default=None)

    op.add_column("craving_sessions", sa.Column("goal_id", sa.Uuid(as_uuid=True), nullable=True))


def downgrade() -> None:
    op.drop_column("craving_sessions", "goal_id")

    with op.batch_alter_table("monthly_goals") as batch_op:
        batch_op.drop_column("progress")
        batch_op.drop_column("unit")
        batch_op.drop_column("target")
        batch_op.create_unique_constraint("uq_monthly_goals_user_month", ["user_id", "month"])
