from dataclasses import dataclass
from datetime import date
from uuid import UUID

MAX_ACTIVE_GOALS = 5


@dataclass
class MonthlyGoal:
    id: UUID
    user_id: UUID
    month: date  # always the 1st of the month; time-of-day is irrelevant
    title: str
    target: int
    unit: str
    progress: int = 0

    @property
    def is_complete(self) -> bool:
        return self.progress >= self.target


def month_key_for(value: date) -> date:
    return value.replace(day=1)
