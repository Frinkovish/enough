import logging
from datetime import date

from app.core.config import Settings
from app.core.time_of_day import day_part
from app.integrations.azure_openai_boo_chat import AzureOpenAIBooChat, BooChatUnavailableError
from app.integrations.supabase_admin_client import (
    SupabaseAdminError,
    get_conversation_history,
    get_recent_sessions,
    get_reminder_context,
    save_conversation_turn,
)

logger = logging.getLogger("app.boo_conversation")

# Matches the frontend's QuitReasonWire.label — see reminder_service.py.
_QUIT_REASON_LABELS = {
    "health": "health",
    "family": "family",
    "money": "saving money",
    "fitness": "fitness",
    "pregnancy": "pregnancy",
    "social_pressure": "social pressure",
    "other": "their own reasons",
}


class BooConversationNotConfiguredError(Exception):
    pass


async def reply_to_message(settings: Settings, message: str) -> str:
    if not (
        settings.azure_openai_endpoint
        and settings.azure_openai_api_key
        and settings.supabase_service_role_key
        and settings.reminder_user_id
    ):
        raise BooConversationNotConfiguredError("Boo Conversations is not fully configured")

    user_id = settings.reminder_user_id

    try:
        context = await get_reminder_context(
            supabase_url=settings.supabase_url,
            service_role_key=settings.supabase_service_role_key,
            user_id=user_id,
        )
    except SupabaseAdminError as exc:
        logger.warning("Failed to fetch profile context for Boo chat: %s", exc)
        context = None

    try:
        recent_sessions = await get_recent_sessions(
            supabase_url=settings.supabase_url,
            service_role_key=settings.supabase_service_role_key,
            user_id=user_id,
        )
    except SupabaseAdminError as exc:
        logger.warning("Failed to fetch recent sessions for Boo chat: %s", exc)
        recent_sessions = []

    try:
        history = await get_conversation_history(
            supabase_url=settings.supabase_url,
            service_role_key=settings.supabase_service_role_key,
            user_id=user_id,
        )
    except SupabaseAdminError as exc:
        logger.warning("Failed to fetch conversation history for Boo chat: %s", exc)
        history = []

    days_clean = None
    if context and context.quit_date is not None:
        days_clean = (date.today() - date.fromisoformat(context.quit_date)).days

    quit_reason_labels = (
        [_QUIT_REASON_LABELS.get(reason, reason) for reason in context.quit_reasons] if context else []
    )

    chat = AzureOpenAIBooChat(
        settings.azure_openai_endpoint, settings.azure_openai_api_key, model=settings.azure_openai_model
    )
    try:
        reply = await chat.reply(
            display_name=context.display_name if context else None,
            day_part=day_part(settings.reminder_timezone),
            days_clean=days_clean,
            target=context.days_clean_target if context else None,
            quit_reasons=quit_reason_labels,
            goals=context.goals if context else [],
            recent_sessions=recent_sessions,
            history=history,
            message=message,
        )
    except BooChatUnavailableError as exc:
        logger.warning("Boo chat AI call failed: %s", exc)
        reply = "Sorry, I'm having trouble thinking right now — try again in a moment?"

    # Best-effort: a failed write shouldn't break the reply the user's
    # about to receive, just cost some future memory.
    try:
        await save_conversation_turn(
            supabase_url=settings.supabase_url,
            service_role_key=settings.supabase_service_role_key,
            user_id=user_id,
            role="user",
            content=message,
        )
        await save_conversation_turn(
            supabase_url=settings.supabase_url,
            service_role_key=settings.supabase_service_role_key,
            user_id=user_id,
            role="assistant",
            content=reply,
        )
    except SupabaseAdminError as exc:
        logger.warning("Failed to persist conversation turn: %s", exc)

    return reply
