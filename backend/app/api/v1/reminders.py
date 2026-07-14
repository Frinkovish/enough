import secrets

from fastapi import APIRouter, Header, HTTPException, status

from app.api.deps import CurrentUserId
from app.core.config import get_settings
from app.services.reminder_service import ReminderNotConfiguredError, send_daily_reminder

router = APIRouter(prefix="/reminders", tags=["reminders"])


@router.post("/daily")
async def trigger_daily_reminder(
    x_reminder_secret: str | None = Header(default=None),
) -> dict[str, str]:
    """Triggered by an external scheduler (this repo's daily-reminder
    GitHub Actions workflow), not by the app itself — there's no user
    session at send time, so this is gated by a shared secret instead of
    the usual Supabase JWT auth.
    """
    settings = get_settings()
    if not settings.reminder_secret or not secrets.compare_digest(
        x_reminder_secret or "", settings.reminder_secret
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid reminder secret")

    try:
        await send_daily_reminder(settings)
    except ReminderNotConfiguredError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return {"status": "sent"}


@router.post("/test")
async def trigger_test_reminder(user_id: CurrentUserId) -> dict[str, str]:
    """Manual "send it now" button in the app, so the reminder mechanism
    can be tested without waiting for the daily cron. Reuses normal
    Supabase auth (unlike /daily, which has no user session) but is still
    restricted to the single configured reminder recipient — this isn't a
    general per-user feature.
    """
    settings = get_settings()
    if not settings.reminder_user_id or str(user_id) != settings.reminder_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized for this action")

    try:
        await send_daily_reminder(settings)
    except ReminderNotConfiguredError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return {"status": "sent"}
