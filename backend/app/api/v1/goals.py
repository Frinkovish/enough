from datetime import date

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserId, GoalParsingServiceDep, GoalServiceDep
from app.schemas.goal import CreateGoalRequest, GoalRead
from app.schemas.goal_parse import ParsedGoalRead, ParseGoalRequest
from app.services.goal_service import TooManyActiveGoalsError

router = APIRouter(prefix="/goals", tags=["goals"])


@router.get("", response_model=list[GoalRead])
async def list_active_goals(user_id: CurrentUserId, service: GoalServiceDep) -> list[GoalRead]:
    goals = await service.get_active_goals(user_id, date.today())
    return [GoalRead.from_domain(goal) for goal in goals]


@router.post("/parse", response_model=ParsedGoalRead)
async def parse_goal(
    payload: ParseGoalRequest,
    user_id: CurrentUserId,  # noqa: ARG001 — auth gate only
    service: GoalParsingServiceDep,
) -> ParsedGoalRead:
    parsed = await service.parse(payload.description)
    return ParsedGoalRead.from_domain(parsed)


@router.post("", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
async def create_goal(
    payload: CreateGoalRequest,
    user_id: CurrentUserId,
    service: GoalServiceDep,
) -> GoalRead:
    try:
        goal = await service.create_goal(
            user_id, date.today(), payload.title, payload.target, payload.unit
        )
    except TooManyActiveGoalsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You've reached the limit of 5 active goals.",
        ) from exc
    return GoalRead.from_domain(goal)
