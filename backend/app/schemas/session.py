from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from app.domain.craving_trigger import CravingTrigger
from app.domain.session import CravingSession, SessionOutcome
from app.domain.stats import CravingStats
from app.domain.task_suggestion import TaskCategory


class TaskSuggestionRead(BaseModel):
    id: str
    title: str
    description: str
    category: TaskCategory


class SessionRead(BaseModel):
    id: UUID
    started_at: datetime
    duration_seconds: int
    suggested_task: TaskSuggestionRead
    trigger: CravingTrigger
    goal_id: UUID | None
    outcome: SessionOutcome | None
    completed_at: datetime | None

    @classmethod
    def from_domain(cls, session: CravingSession) -> "SessionRead":
        return cls(
            id=session.id,
            started_at=session.started_at,
            duration_seconds=session.duration_seconds,
            suggested_task=TaskSuggestionRead(
                id=session.suggested_task.id,
                title=session.suggested_task.title,
                description=session.suggested_task.description,
                category=session.suggested_task.category,
            ),
            trigger=session.trigger,
            goal_id=session.goal_id,
            outcome=session.outcome,
            completed_at=session.completed_at,
        )


class StartSessionRequest(BaseModel):
    trigger: CravingTrigger
    goal_id: UUID | None = None


class CompleteSessionRequest(BaseModel):
    outcome: SessionOutcome


class StatsRead(BaseModel):
    total_delayed: int
    current_streak: int

    @classmethod
    def from_domain(cls, stats: CravingStats) -> "StatsRead":
        return cls(total_delayed=stats.total_delayed, current_streak=stats.current_streak)
