from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserId, GoalServiceDep, SessionServiceDep
from app.domain.session import SessionOutcome
from app.schemas.session import CompleteSessionRequest, SessionRead, StartSessionRequest, StatsRead
from app.services.session_service import SessionAlreadyCompleteError, SessionNotFoundError

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("", response_model=SessionRead, status_code=status.HTTP_201_CREATED)
async def start_session(
    payload: StartSessionRequest,
    user_id: CurrentUserId,
    service: SessionServiceDep,
) -> SessionRead:
    session = await service.start_session(user_id, payload.trigger, payload.goal_id)
    return SessionRead.from_domain(session)


@router.post("/{session_id}/complete", response_model=SessionRead)
async def complete_session(
    session_id: UUID,
    payload: CompleteSessionRequest,
    user_id: CurrentUserId,
    service: SessionServiceDep,
    goal_service: GoalServiceDep,
) -> SessionRead:
    try:
        session = await service.complete_session(session_id, user_id, payload.outcome)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found") from exc
    except SessionAlreadyCompleteError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Session already completed"
        ) from exc

    if session.outcome == SessionOutcome.DID_NOT_SMOKE and session.goal_id is not None:
        await goal_service.increment_progress(session.goal_id)

    return SessionRead.from_domain(session)


@router.get("", response_model=list[SessionRead])
async def list_sessions(user_id: CurrentUserId, service: SessionServiceDep) -> list[SessionRead]:
    sessions = await service.list_sessions(user_id)
    return [SessionRead.from_domain(session) for session in sessions]


@router.get("/stats", response_model=StatsRead)
async def get_stats(user_id: CurrentUserId, service: SessionServiceDep) -> StatsRead:
    stats = await service.get_stats(user_id)
    return StatsRead.from_domain(stats)
