from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.goal_repository import GoalRepository
from app.domain.monthly_goal import MonthlyGoal, month_key_for
from app.models.goal_model import MonthlyGoalModel


class SQLAlchemyGoalRepository(GoalRepository):
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def list_for_month(self, user_id: UUID, month: date) -> list[MonthlyGoal]:
        result = await self._db.execute(
            select(MonthlyGoalModel)
            .where(
                MonthlyGoalModel.user_id == user_id,
                MonthlyGoalModel.month == month_key_for(month),
            )
            .order_by(MonthlyGoalModel.created_at.asc())
        )
        return [_to_domain(model) for model in result.scalars().all()]

    async def add(self, goal: MonthlyGoal) -> MonthlyGoal:
        model = MonthlyGoalModel(
            id=goal.id,
            user_id=goal.user_id,
            month=goal.month,
            title=goal.title,
            target=goal.target,
            unit=goal.unit,
            progress=goal.progress,
        )
        self._db.add(model)
        await self._db.commit()
        await self._db.refresh(model)
        return _to_domain(model)

    async def increment_progress(self, goal_id: UUID) -> MonthlyGoal | None:
        model = await self._db.get(MonthlyGoalModel, goal_id)
        if model is None:
            return None
        if model.progress < model.target:
            model.progress += 1
            await self._db.commit()
            await self._db.refresh(model)
        return _to_domain(model)


def _to_domain(model: MonthlyGoalModel) -> MonthlyGoal:
    return MonthlyGoal(
        id=model.id,
        user_id=model.user_id,
        month=model.month,
        title=model.title,
        target=model.target,
        unit=model.unit,
        progress=model.progress,
    )
