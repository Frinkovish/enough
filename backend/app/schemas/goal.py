from uuid import UUID

from pydantic import BaseModel, Field

from app.domain.monthly_goal import MonthlyGoal


class GoalRead(BaseModel):
    id: UUID
    title: str
    target: int
    unit: str
    progress: int

    @classmethod
    def from_domain(cls, goal: MonthlyGoal) -> "GoalRead":
        return cls(
            id=goal.id,
            title=goal.title,
            target=goal.target,
            unit=goal.unit,
            progress=goal.progress,
        )


class CreateGoalRequest(BaseModel):
    title: str
    target: int = Field(ge=1)
    unit: str
