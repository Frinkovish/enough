from datetime import date
from uuid import UUID, uuid4

from app.domain.goal_repository import GoalRepository
from app.domain.monthly_goal import MAX_ACTIVE_GOALS, MonthlyGoal, month_key_for


class TooManyActiveGoalsError(Exception):
    pass


class GoalService:
    """Up to MAX_ACTIVE_GOALS goals at once. Progress lives on the goal
    itself and is credited directly (see session completion in the API
    layer) rather than recomputed from session history each time.
    """

    def __init__(self, repository: GoalRepository) -> None:
        self._repository = repository

    async def get_active_goals(self, user_id: UUID, today: date) -> list[MonthlyGoal]:
        goals = await self._repository.list_for_month(user_id, today)
        return [g for g in goals if not g.is_complete]

    async def create_goal(
        self, user_id: UUID, today: date, title: str, target: int, unit: str
    ) -> MonthlyGoal:
        active = await self.get_active_goals(user_id, today)
        if len(active) >= MAX_ACTIVE_GOALS:
            raise TooManyActiveGoalsError(user_id)

        goal = MonthlyGoal(
            id=uuid4(),
            user_id=user_id,
            month=month_key_for(today),
            title=title,
            target=target,
            unit=unit,
        )
        return await self._repository.add(goal)

    async def increment_progress(self, goal_id: UUID) -> MonthlyGoal | None:
        return await self._repository.increment_progress(goal_id)
