from fastapi import APIRouter

from app.api.deps import CurrentUserId, SuggestionServiceDep
from app.schemas.suggestion import SuggestionRead, SuggestionRequest

router = APIRouter(prefix="/suggestions", tags=["suggestions"])


@router.post("", response_model=SuggestionRead)
async def get_suggestion(
    payload: SuggestionRequest,
    user_id: CurrentUserId,  # noqa: ARG001 — auth gate; the suggestion itself doesn't need the id
    service: SuggestionServiceDep,
) -> SuggestionRead:
    goals = [goal.to_domain() for goal in payload.goals]
    recent_interventions = [intervention.to_domain() for intervention in payload.recent_interventions]
    suggestion = await service.get_suggestion(
        payload.trigger,
        goals,
        payload.local_hour,
        payload.energy,
        payload.intensity,
        recent_interventions,
        payload.location_context,
        payload.addiction_type,
    )
    return SuggestionRead.from_domain(suggestion)
