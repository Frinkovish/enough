from abc import ABC, abstractmethod

from app.domain.craving_intensity import CravingIntensity
from app.domain.craving_trigger import CravingTrigger
from app.domain.energy_level import EnergyLevel
from app.domain.goal_context import GoalContext
from app.domain.location_context import LocationContext
from app.domain.recent_intervention import RecentIntervention
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
        energy: EnergyLevel,
        intensity: CravingIntensity,
        recent_interventions: list[RecentIntervention],
        location_context: LocationContext | None = None,
    ) -> TaskSuggestion: ...
