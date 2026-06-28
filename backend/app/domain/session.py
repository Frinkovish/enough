from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from uuid import UUID

from app.domain.craving_trigger import CravingTrigger
from app.domain.task_suggestion import TaskSuggestion

DEFAULT_SESSION_DURATION_SECONDS = 20 * 60


class SessionOutcome(str, Enum):
    SMOKED = "smoked"
    DID_NOT_SMOKE = "did_not_smoke"


@dataclass
class CravingSession:
    id: UUID
    user_id: UUID
    started_at: datetime
    duration_seconds: int
    suggested_task: TaskSuggestion
    trigger: CravingTrigger
    goal_id: UUID | None = None
    outcome: SessionOutcome | None = None
    completed_at: datetime | None = None

    @property
    def is_complete(self) -> bool:
        return self.outcome is not None
