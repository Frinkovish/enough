import logging

from app.domain.craving_intensity import CravingIntensity
from app.domain.craving_trigger import CravingTrigger
from app.domain.energy_level import EnergyLevel
from app.domain.goal_context import GoalContext
from app.domain.location_context import LocationContext
from app.domain.recent_intervention import RecentIntervention
from app.domain.suggestion_generator import SuggestionGenerator
from app.domain.task_suggestion import TaskSuggestion, pick_random_suggestion

logger = logging.getLogger("app.suggestions")


class SuggestionService:
    """Generates a task suggestion for a craving session.

    Falls back to the static suggestion pool whenever AI generation
    isn't configured or fails for any reason — a slow or broken AI
    provider should never block someone from starting their delay.
    """

    def __init__(self, generator: SuggestionGenerator | None) -> None:
        self._generator = generator

    async def get_suggestion(
        self,
        trigger: CravingTrigger,
        goals: list[GoalContext],
        local_hour: int,
        energy: EnergyLevel,
        intensity: CravingIntensity,
        recent_interventions: list[RecentIntervention],
        location_context: LocationContext | None = None,
    ) -> TaskSuggestion:
        if self._generator is None:
            logger.info("No AI generator configured, using static suggestion pool")
        else:
            try:
                return await self._generator.generate(
                    trigger, goals, local_hour, energy, intensity, recent_interventions, location_context
                )
            except Exception as exc:  # noqa: BLE001 — any AI failure must fall back, not break the loop
                logger.warning("AI generator raised %r, falling back to static pool", exc)

        return pick_random_suggestion()
