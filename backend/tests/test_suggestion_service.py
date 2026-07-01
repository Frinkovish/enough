from app.domain.craving_intensity import CravingIntensity
from app.domain.craving_trigger import CravingTrigger
from app.domain.energy_level import EnergyLevel
from app.domain.goal_context import GoalContext
from app.domain.recent_intervention import RecentIntervention
from app.domain.suggestion_generator import SuggestionGenerator
from app.domain.task_suggestion import TaskCategory, TaskSuggestion
from app.services.suggestion_service import SuggestionService

_ENERGY = EnergyLevel.OKAY
_INTENSITY = CravingIntensity.MODERATE


class _FakeGenerator(SuggestionGenerator):
    def __init__(self, result: TaskSuggestion | None = None, error: Exception | None = None) -> None:
        self._result = result
        self._error = error

    async def generate(
        self,
        trigger: CravingTrigger,
        goals: list[GoalContext],
        local_hour: int,
        energy: EnergyLevel,
        intensity: CravingIntensity,
        recent_interventions: list[RecentIntervention],
        location_context=None,
    ) -> TaskSuggestion:
        if self._error is not None:
            raise self._error
        assert self._result is not None
        return self._result


async def test_no_generator_configured_falls_back_to_static_pool() -> None:
    service = SuggestionService(None)

    suggestion = await service.get_suggestion(CravingTrigger.HABIT, [], 14, _ENERGY, _INTENSITY, [])

    assert suggestion is not None


async def test_generator_failure_falls_back_to_static_pool() -> None:
    generator = _FakeGenerator(error=RuntimeError("AI is down"))
    service = SuggestionService(generator)

    suggestion = await service.get_suggestion(CravingTrigger.HABIT, [], 14, _ENERGY, _INTENSITY, [])

    assert suggestion is not None
    assert not suggestion.id.startswith("ai:")


async def test_generator_success_is_used() -> None:
    ai_suggestion = TaskSuggestion(
        id="ai:test", title="Breathe", description="Slowly.", category=TaskCategory.BREATHING
    )
    generator = _FakeGenerator(result=ai_suggestion)
    service = SuggestionService(generator)

    suggestion = await service.get_suggestion(CravingTrigger.HABIT, [], 14, _ENERGY, _INTENSITY, [])

    assert suggestion == ai_suggestion
