from datetime import datetime, timezone
from uuid import UUID, uuid4

from app.domain.craving_trigger import CravingTrigger
from app.domain.session import DEFAULT_SESSION_DURATION_SECONDS, CravingSession, SessionOutcome
from app.domain.session_repository import SessionRepository
from app.domain.stats import CravingStats
from app.domain.task_suggestion import pick_random_suggestion


class SessionNotFoundError(Exception):
    pass


class SessionAlreadyCompleteError(Exception):
    pass


class SessionService:
    """Business rules for the 20-minute craving delay loop.

    Owns when a session can be created or completed; the repository
    only knows how to persist and fetch, never when that's valid.
    """

    def __init__(self, repository: SessionRepository) -> None:
        self._repository = repository

    async def start_session(
        self, user_id: UUID, trigger: CravingTrigger, goal_id: UUID | None = None
    ) -> CravingSession:
        session = CravingSession(
            id=uuid4(),
            user_id=user_id,
            started_at=datetime.now(timezone.utc),
            duration_seconds=DEFAULT_SESSION_DURATION_SECONDS,
            suggested_task=pick_random_suggestion(),
            trigger=trigger,
            goal_id=goal_id,
        )
        return await self._repository.add(session)

    async def complete_session(
        self, session_id: UUID, user_id: UUID, outcome: SessionOutcome
    ) -> CravingSession:
        session = await self._repository.get(session_id)
        if session is None or session.user_id != user_id:
            raise SessionNotFoundError(session_id)
        if session.is_complete:
            raise SessionAlreadyCompleteError(session_id)

        updated = await self._repository.update_outcome(
            session_id=session_id,
            outcome=outcome,
            completed_at=datetime.now(timezone.utc),
        )
        if updated is None:
            raise SessionNotFoundError(session_id)
        return updated

    async def list_sessions(self, user_id: UUID) -> list[CravingSession]:
        return await self._repository.list_for_user(user_id)

    async def get_stats(self, user_id: UUID) -> CravingStats:
        sessions = await self._repository.list_for_user(user_id)
        completed = [s for s in sessions if s.completed_at is not None]
        completed.sort(key=lambda s: s.completed_at or datetime.min, reverse=True)

        total_delayed = sum(1 for s in completed if s.outcome == SessionOutcome.DID_NOT_SMOKE)

        current_streak = 0
        for s in completed:
            if s.outcome != SessionOutcome.DID_NOT_SMOKE:
                break
            current_streak += 1

        return CravingStats(total_delayed=total_delayed, current_streak=current_streak)
