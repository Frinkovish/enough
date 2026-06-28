from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.craving_trigger import CravingTrigger
from app.domain.session import SessionOutcome
from app.repositories.sqlalchemy_session_repository import SQLAlchemySessionRepository
from app.services.session_service import (
    SessionAlreadyCompleteError,
    SessionNotFoundError,
    SessionService,
)


@pytest.fixture
def service(db_session: AsyncSession) -> SessionService:
    return SessionService(SQLAlchemySessionRepository(db_session))


async def test_start_session_creates_session_with_a_task_suggestion(service: SessionService) -> None:
    user_id = uuid4()

    session = await service.start_session(user_id, CravingTrigger.STRESS)

    assert session.user_id == user_id
    assert session.trigger == CravingTrigger.STRESS
    assert session.outcome is None
    assert session.duration_seconds == 20 * 60
    assert session.suggested_task is not None


async def test_complete_session_records_outcome(service: SessionService) -> None:
    user_id = uuid4()
    session = await service.start_session(user_id, CravingTrigger.BOREDOM)

    completed = await service.complete_session(session.id, user_id, SessionOutcome.DID_NOT_SMOKE)

    assert completed.outcome == SessionOutcome.DID_NOT_SMOKE
    assert completed.completed_at is not None


async def test_complete_session_twice_raises(service: SessionService) -> None:
    user_id = uuid4()
    session = await service.start_session(user_id, CravingTrigger.HABIT)
    await service.complete_session(session.id, user_id, SessionOutcome.SMOKED)

    with pytest.raises(SessionAlreadyCompleteError):
        await service.complete_session(session.id, user_id, SessionOutcome.DID_NOT_SMOKE)


async def test_complete_session_wrong_user_raises_not_found(service: SessionService) -> None:
    owner_id = uuid4()
    other_user_id = uuid4()
    session = await service.start_session(owner_id, CravingTrigger.SOCIAL)

    with pytest.raises(SessionNotFoundError):
        await service.complete_session(session.id, other_user_id, SessionOutcome.SMOKED)


async def test_list_sessions_returns_only_that_users_sessions(service: SessionService) -> None:
    user_id = uuid4()
    other_user_id = uuid4()
    await service.start_session(user_id, CravingTrigger.OTHER)
    await service.start_session(user_id, CravingTrigger.OTHER)
    await service.start_session(other_user_id, CravingTrigger.OTHER)

    sessions = await service.list_sessions(user_id)

    assert len(sessions) == 2
    assert all(session.user_id == user_id for session in sessions)


async def test_stats_counts_total_delayed_and_current_streak(service: SessionService) -> None:
    user_id = uuid4()

    s1 = await service.start_session(user_id, CravingTrigger.STRESS)
    await service.complete_session(s1.id, user_id, SessionOutcome.SMOKED)

    s2 = await service.start_session(user_id, CravingTrigger.STRESS)
    await service.complete_session(s2.id, user_id, SessionOutcome.DID_NOT_SMOKE)

    s3 = await service.start_session(user_id, CravingTrigger.STRESS)
    await service.complete_session(s3.id, user_id, SessionOutcome.DID_NOT_SMOKE)

    stats = await service.get_stats(user_id)

    assert stats.total_delayed == 2
    assert stats.current_streak == 2


async def test_stats_streak_resets_after_a_relapse(service: SessionService) -> None:
    user_id = uuid4()

    s1 = await service.start_session(user_id, CravingTrigger.STRESS)
    await service.complete_session(s1.id, user_id, SessionOutcome.DID_NOT_SMOKE)

    s2 = await service.start_session(user_id, CravingTrigger.STRESS)
    await service.complete_session(s2.id, user_id, SessionOutcome.SMOKED)

    stats = await service.get_stats(user_id)

    assert stats.total_delayed == 1
    assert stats.current_streak == 0
