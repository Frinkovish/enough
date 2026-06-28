from fastapi import APIRouter

from app.api.v1.goals import router as goals_router
from app.api.v1.suggestions import router as suggestions_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(goals_router)
api_router.include_router(suggestions_router)
