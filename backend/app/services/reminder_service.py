import logging
from datetime import date

from app.core.config import Settings
from app.integrations.supabase_admin_client import ProfileFetchError, get_days_clean_info
from app.integrations.telegram_bot import send_telegram_message

logger = logging.getLogger("app.reminders")


class ReminderNotConfiguredError(Exception):
    pass


def _build_message(quit_date_str: str | None, target: int | None) -> str:
    if quit_date_str is None:
        return "Today's a good day to stay clean. Boo's rooting for you. 💚"

    days_clean = (date.today() - date.fromisoformat(quit_date_str)).days
    if target:
        return f"Day {days_clean} of {target} — keep going, you've got this. 💪"
    return f"Day {days_clean} clean — keep going, you've got this. 💪"


async def send_daily_reminder(settings: Settings) -> None:
    if not (settings.telegram_bot_token and settings.telegram_chat_id):
        raise ReminderNotConfiguredError("Telegram/reminder settings are not fully configured")

    quit_date_str: str | None = None
    target: int | None = None
    if settings.supabase_service_role_key and settings.reminder_user_id:
        try:
            quit_date_str, target = await get_days_clean_info(
                supabase_url=settings.supabase_url,
                service_role_key=settings.supabase_service_role_key,
                user_id=settings.reminder_user_id,
            )
        except ProfileFetchError as exc:
            # A failed profile lookup shouldn't block the reminder itself —
            # fall back to the generic message instead.
            logger.warning("Failed to fetch days-clean info, using generic message: %s", exc)

    body = _build_message(quit_date_str, target)
    logger.info("Sending daily Telegram reminder: %r", body)
    await send_telegram_message(
        bot_token=settings.telegram_bot_token,
        chat_id=settings.telegram_chat_id,
        text=body,
    )
