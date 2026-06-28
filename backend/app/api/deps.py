from typing import Annotated
from uuid import UUID

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import get_current_user_id
from app.db.session import get_db
from app.domain.goal_parser import GoalParser
from app.domain.suggestion_generator import SuggestionGenerator
from app.integrations.azure_openai_goal_parser import AzureOpenAIGoalParser
from app.integrations.azure_openai_suggestion_generator import AzureOpenAISuggestionGenerator
from app.repositories.sqlalchemy_goal_repository import SQLAlchemyGoalRepository
from app.repositories.sqlalchemy_session_repository import SQLAlchemySessionRepository
from app.services.goal_parsing_service import GoalParsingService
from app.services.goal_service import GoalService
from app.services.session_service import SessionService
from app.services.suggestion_service import SuggestionService

CurrentUserId = Annotated[UUID, Depends(get_current_user_id)]


def get_session_service(db: Annotated[AsyncSession, Depends(get_db)]) -> SessionService:
    return SessionService(SQLAlchemySessionRepository(db))


SessionServiceDep = Annotated[SessionService, Depends(get_session_service)]


def get_goal_service(db: Annotated[AsyncSession, Depends(get_db)]) -> GoalService:
    return GoalService(SQLAlchemyGoalRepository(db))


GoalServiceDep = Annotated[GoalService, Depends(get_goal_service)]


def get_suggestion_generator() -> SuggestionGenerator | None:
    settings = get_settings()
    if not settings.azure_openai_endpoint or not settings.azure_openai_api_key:
        return None
    return AzureOpenAISuggestionGenerator(settings.azure_openai_endpoint, settings.azure_openai_api_key)


def get_suggestion_service(
    generator: Annotated[SuggestionGenerator | None, Depends(get_suggestion_generator)],
) -> SuggestionService:
    return SuggestionService(generator)


SuggestionServiceDep = Annotated[SuggestionService, Depends(get_suggestion_service)]


def get_goal_parser() -> GoalParser | None:
    settings = get_settings()
    if not settings.azure_openai_endpoint or not settings.azure_openai_api_key:
        return None
    return AzureOpenAIGoalParser(settings.azure_openai_endpoint, settings.azure_openai_api_key)


def get_goal_parsing_service(
    parser: Annotated[GoalParser | None, Depends(get_goal_parser)],
) -> GoalParsingService:
    return GoalParsingService(parser)


GoalParsingServiceDep = Annotated[GoalParsingService, Depends(get_goal_parsing_service)]
