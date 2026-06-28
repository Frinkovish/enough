from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.craving_trigger import CravingTrigger
from app.domain.session import CravingSession, SessionOutcome
from app.domain.session_repository import SessionRepository
from app.domain.task_suggestion import get_suggestion_by_id
from app.models.session_model import CravingSessionModel


class SQLAlchemySessionRepository(SessionRepository):
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def add(self, session: CravingSession) -> CravingSession:
        model = CravingSessionModel(
            id=session.id,
            user_id=session.user_id,
            started_at=session.started_at,
            duration_seconds=session.duration_seconds,
            suggested_task_id=session.suggested_task.id,
            trigger=session.trigger.value,
            goal_id=session.goal_id,
            outcome=session.outcome.value if session.outcome else None,
            completed_at=session.completed_at,
        )
        self._db.add(model)
        await self._db.commit()
        await self._db.refresh(model)
        return _to_domain(model)

    async def get(self, session_id: UUID) -> CravingSession | None:
        model = await self._db.get(CravingSessionModel, session_id)
        return _to_domain(model) if model else None

    async def update_outcome(
        self,
        session_id: UUID,
        outcome: SessionOutcome,
        completed_at: datetime,
    ) -> CravingSession | None:
        model = await self._db.get(CravingSessionModel, session_id)
        if model is None:
            return None
        model.outcome = outcome.value
        model.completed_at = completed_at
        await self._db.commit()
        await self._db.refresh(model)
        return _to_domain(model)

    async def list_for_user(self, user_id: UUID) -> list[CravingSession]:
        result = await self._db.execute(
            select(CravingSessionModel).where(CravingSessionModel.user_id == user_id)
        )
        return [_to_domain(model) for model in result.scalars().all()]


def _to_domain(model: CravingSessionModel) -> CravingSession:
    return CravingSession(
        id=model.id,
        user_id=model.user_id,
        started_at=model.started_at,
        duration_seconds=model.duration_seconds,
        suggested_task=get_suggestion_by_id(model.suggested_task_id),
        trigger=CravingTrigger(model.trigger),
        goal_id=model.goal_id,
        outcome=SessionOutcome(model.outcome) if model.outcome else None,
        completed_at=model.completed_at,
    )
