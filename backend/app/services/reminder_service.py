import logging
from datetime import date, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.core.config import Settings
from app.integrations.azure_openai_reminder_generator import (
    AzureOpenAIReminderGenerator,
    ReminderMessageUnavailableError,
)
from app.integrations.supabase_admin_client import ProfileFetchError, ReminderContext, get_reminder_context
from app.integrations.telegram_bot import send_telegram_message

logger = logging.getLogger("app.reminders")

# Matches the frontend's QuitReasonWire.label (frontend/lib/features/profile/domain/user_profile.dart)
# so a reason read back from the profile displays the same way it does in the app.
_QUIT_REASON_LABELS = {
    "health": "health",
    "family": "family",
    "money": "saving money",
    "fitness": "fitness",
    "pregnancy": "pregnancy",
    "social_pressure": "social pressure",
    "other": "their own reasons",
}


class ReminderNotConfiguredError(Exception):
    pass


def _day_part(timezone_name: str) -> str:
    try:
        hour = datetime.now(ZoneInfo(timezone_name)).hour
    except ZoneInfoNotFoundError:
        logger.warning("Unknown REMINDER_TIMEZONE %r, defaulting to UTC", timezone_name)
        hour = datetime.now(ZoneInfo("UTC")).hour
    if 5 <= hour < 12:
        return "morning"
    if 12 <= hour < 17:
        return "afternoon"
    if 17 <= hour < 22:
        return "evening"
    return "night"


def _static_message(
    display_name: str | None, days_clean: int | None, target: int | None, occasion: str
) -> str:
    name = f"{display_name}, " if display_name else ""
    if occasion == "morning":
        greeting = f"Good morning, {display_name}" if display_name else "Good morning"
        return f"{greeting} — time to start the day clean. Boo's got your back. 🌅"
    if days_clean is None:
        return f"{name}today's a good day to stay clean. Boo's rooting for you. 💚"
    if target:
        return f"{name}day {days_clean} of {target} — keep going, you've got this. 💪"
    return f"{name}day {days_clean} clean — keep going, you've got this. 💪"


async def _build_message(
    settings: Settings, days_clean: int | None, context: ReminderContext, occasion: str
) -> str:
    """A fresh, human-written line from the AI each time, personalized
    with whatever profile/goal context is available — falls back to a
    static message if the AI isn't configured or fails."""
    if settings.azure_openai_endpoint and settings.azure_openai_api_key:
        try:
            generator = AzureOpenAIReminderGenerator(
                settings.azure_openai_endpoint,
                settings.azure_openai_api_key,
                model=settings.azure_openai_model,
            )
            quit_reason_labels = [_QUIT_REASON_LABELS.get(reason, reason) for reason in context.quit_reasons]
            return await generator.generate(
                display_name=context.display_name,
                day_part=_day_part(settings.reminder_timezone),
                days_clean=days_clean,
                target=context.days_clean_target,
                quit_reasons=quit_reason_labels,
                goals=context.goals,
                occasion=occasion,
            )
        except ReminderMessageUnavailableError as exc:
            logger.warning("Reminder AI generation failed, using static message: %s", exc)

    return _static_message(context.display_name, days_clean, context.days_clean_target, occasion)


async def send_daily_reminder(settings: Settings, occasion: str = "general") -> None:
    if not (settings.telegram_bot_token and settings.telegram_chat_id):
        raise ReminderNotConfiguredError("Telegram/reminder settings are not fully configured")
    if occasion not in ("general", "morning"):
        occasion = "general"

    context = ReminderContext(display_name=None, quit_date=None, days_clean_target=None)
    if settings.supabase_service_role_key and settings.reminder_user_id:
        try:
            context = await get_reminder_context(
                supabase_url=settings.supabase_url,
                service_role_key=settings.supabase_service_role_key,
                user_id=settings.reminder_user_id,
            )
        except ProfileFetchError as exc:
            # A failed profile lookup shouldn't block the reminder itself —
            # fall back to the generic message instead.
            logger.warning("Failed to fetch reminder context, using generic message: %s", exc)

    days_clean = None
    if context.quit_date is not None:
        days_clean = (date.today() - date.fromisoformat(context.quit_date)).days

    body = await _build_message(settings, days_clean, context, occasion)
    logger.info("Sending %s Telegram reminder: %r", occasion, body)
    await send_telegram_message(
        bot_token=settings.telegram_bot_token,
        chat_id=settings.telegram_chat_id,
        text=body,
    )
