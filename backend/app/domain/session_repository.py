from abc import ABC, abstractmethod
from datetime import datetime
from uuid import UUID

from app.domain.session import CravingSession, SessionOutcome


class SessionRepository(ABC):
    """Persistence contract for craving sessions.

    The service layer depends on this interface, never on SQLAlchemy
    directly, so the storage backend can be swapped without touching
    business logic.
    """

    @abstractmethod
    async def add(self, session: CravingSession) -> CravingSession: ...

    @abstractmethod
    async def get(self, session_id: UUID) -> CravingSession | None: ...

    @abstractmethod
    async def update_outcome(
        self,
        session_id: UUID,
        outcome: SessionOutcome,
        completed_at: datetime,
    ) -> CravingSession | None: ...

    @abstractmethod
    async def list_for_user(self, user_id: UUID) -> list[CravingSession]: ...
