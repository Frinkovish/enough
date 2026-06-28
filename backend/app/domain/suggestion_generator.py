from abc import ABC, abstractmethod

from app.domain.craving_trigger import CravingTrigger
from app.domain.goal_context import GoalContext
from app.domain.task_suggestion import TaskSuggestion


class AISuggestionUnavailableError(Exception):
    pass


class SuggestionGenerator(ABC):
    @abstractmethod
    async def generate(
        self,
        trigger: CravingTrigger,
        goals: list[GoalContext],
        local_hour: int,
        last_suggestion_title: str | None,
    ) -> TaskSuggestion: ...
