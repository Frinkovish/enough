from typing import Annotated
from uuid import UUID

from fastapi import Depends

from app.core.config import get_settings
from app.core.security import get_current_user_id
from app.domain.goal_parser import GoalParser
from app.domain.suggestion_generator import SuggestionGenerator
from app.integrations.azure_openai_goal_parser import AzureOpenAIGoalParser
from app.integrations.azure_openai_suggestion_generator import AzureOpenAISuggestionGenerator
from app.services.goal_parsing_service import GoalParsingService
from app.services.suggestion_service import SuggestionService

CurrentUserId = Annotated[UUID, Depends(get_current_user_id)]


def get_suggestion_generator() -> SuggestionGenerator | None:
    settings = get_settings()
    if not settings.azure_openai_endpoint or not settings.azure_openai_api_key:
        return None
    return AzureOpenAISuggestionGenerator(
        settings.azure_openai_endpoint, settings.azure_openai_api_key, model=settings.azure_openai_model
    )


def get_suggestion_service(
    generator: Annotated[SuggestionGenerator | None, Depends(get_suggestion_generator)],
) -> SuggestionService:
    return SuggestionService(generator)


SuggestionServiceDep = Annotated[SuggestionService, Depends(get_suggestion_service)]


def get_goal_parser() -> GoalParser | None:
    settings = get_settings()
    if not settings.azure_openai_endpoint or not settings.azure_openai_api_key:
        return None
    return AzureOpenAIGoalParser(
        settings.azure_openai_endpoint, settings.azure_openai_api_key, model=settings.azure_openai_model
    )


def get_goal_parsing_service(
    parser: Annotated[GoalParser | None, Depends(get_goal_parser)],
) -> GoalParsingService:
    return GoalParsingService(parser)


GoalParsingServiceDep = Annotated[GoalParsingService, Depends(get_goal_parsing_service)]
