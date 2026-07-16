import logging
import secrets

from fastapi import APIRouter, Header, Request

from app.core.config import get_settings
from app.integrations.telegram_bot import send_telegram_message
from app.services.boo_conversation_service import BooConversationNotConfiguredError, reply_to_message

logger = logging.getLogger("app.boo_conversation")

router = APIRouter(prefix="/telegram", tags=["telegram"])


@router.post("/webhook")
async def telegram_webhook(
    request: Request,
    x_telegram_bot_api_secret_token: str | None = Header(default=None),
) -> dict[str, str]:
    """Receives every message sent to the bot (Telegram calls this
    directly — see setWebhook). Always returns 200 so Telegram doesn't
    retry; anything not worth acting on (wrong chat, non-text message,
    missing config) is just silently dropped rather than erroring.
    """
    settings = get_settings()

    if not settings.telegram_webhook_secret or not secrets.compare_digest(
        x_telegram_bot_api_secret_token or "", settings.telegram_webhook_secret
    ):
        logger.warning("Rejected Telegram webhook call with invalid/missing secret token")
        return {"status": "ignored"}

    update = await request.json()
    message = update.get("message") or update.get("edited_message")
    if not message:
        return {"status": "ignored"}

    chat_id = str(message.get("chat", {}).get("id", ""))
    text = message.get("text")

    if not settings.telegram_bot_token or not settings.telegram_chat_id or chat_id != settings.telegram_chat_id:
        logger.warning("Ignored Telegram message from unrecognized chat %s", chat_id)
        return {"status": "ignored"}

    if not text:
        # Boo only handles text for now — silently skip photos, stickers, etc.
        return {"status": "ignored"}

    try:
        reply = await reply_to_message(settings, text)
    except BooConversationNotConfiguredError as exc:
        logger.warning("Boo Conversations not configured: %s", exc)
        return {"status": "not_configured"}

    await send_telegram_message(bot_token=settings.telegram_bot_token, chat_id=settings.telegram_chat_id, text=reply)
    return {"status": "replied"}
