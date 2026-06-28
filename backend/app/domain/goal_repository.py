from abc import ABC, abstractmethod
from datetime import date
from uuid import UUID

from app.domain.monthly_goal import MonthlyGoal


class GoalRepository(ABC):
    @abstractmethod
    async def list_for_month(self, user_id: UUID, month: date) -> list[MonthlyGoal]: ...

    @abstractmethod
    async def add(self, goal: MonthlyGoal) -> MonthlyGoal: ...

    @abstractmethod
    async def increment_progress(self, goal_id: UUID) -> MonthlyGoal | None: ...
