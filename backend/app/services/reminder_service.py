import logging
from datetime import date

from app.core.config import Settings
from app.integrations.azure_openai_reminder_generator import (
    AzureOpenAIReminderGenerator,
    ReminderMessageUnavailableError,
)
from app.integrations.supabase_admin_client import ProfileFetchError, get_days_clean_info
from app.integrations.telegram_bot import send_telegram_message

logger = logging.getLogger("app.reminders")


class ReminderNotConfiguredError(Exception):
    pass


def _static_message(days_clean: int | None, target: int | None) -> str:
    if days_clean is None:
        return "Today's a good day to stay clean. Boo's rooting for you. 💚"
    if target:
        return f"Day {days_clean} of {target} — keep going, you've got this. 💪"
    return f"Day {days_clean} clean — keep going, you've got this. 💪"


async def _build_message(settings: Settings, days_clean: int | None, target: int | None) -> str:
    """A fresh, human-written line from the AI each time, so it never
    reads like the same template — falls back to a static (but still
    varying-by-progress) message if the AI isn't configured or fails."""
    if settings.azure_openai_endpoint and settings.azure_openai_api_key:
        try:
            generator = AzureOpenAIReminderGenerator(
                settings.azure_openai_endpoint,
                settings.azure_openai_api_key,
                model=settings.azure_openai_model,
            )
            return await generator.generate(days_clean, target)
        except ReminderMessageUnavailableError as exc:
            logger.warning("Reminder AI generation failed, using static message: %s", exc)

    return _static_message(days_clean, target)


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

    days_clean = None
    if quit_date_str is not None:
        days_clean = (date.today() - date.fromisoformat(quit_date_str)).days

    body = await _build_message(settings, days_clean, target)
    logger.info("Sending daily Telegram reminder: %r", body)
    await send_telegram_message(
        bot_token=settings.telegram_bot_token,
        chat_id=settings.telegram_chat_id,
        text=body,
    )
