from fastapi import APIRouter

from app.api.deps import CurrentUserId, GoalParsingServiceDep
from app.schemas.goal_parse import ParsedGoalRead, ParseGoalRequest

router = APIRouter(prefix="/goals", tags=["goals"])


@router.post("/parse", response_model=ParsedGoalRead)
async def parse_goal(
    payload: ParseGoalRequest,
    user_id: CurrentUserId,  # noqa: ARG001 — auth gate only
    service: GoalParsingServiceDep,
) -> ParsedGoalRead:
    parsed = await service.parse(payload.description)
    return ParsedGoalRead.from_domain(parsed)
