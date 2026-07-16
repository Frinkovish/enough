from fastapi import APIRouter

from app.api.v1.goals import router as goals_router
from app.api.v1.reminders import router as reminders_router
from app.api.v1.suggestions import router as suggestions_router
from app.api.v1.telegram_webhook import router as telegram_webhook_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(goals_router)
api_router.include_router(reminders_router)
api_router.include_router(suggestions_router)
api_router.include_router(telegram_webhook_router)
