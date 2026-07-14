import httpx

_SEND_MESSAGE_URL = "https://api.telegram.org/bot{token}/sendMessage"


class TelegramSendError(Exception):
    pass


async def send_telegram_message(*, bot_token: str, chat_id: str, text: str) -> None:
    """Sends a message via the Telegram Bot API — a single authenticated
    POST, no approval process or message templates required (unlike
    WhatsApp's Business Platform)."""
    url = _SEND_MESSAGE_URL.format(token=bot_token)
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(url, json={"chat_id": chat_id, "text": text})
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise TelegramSendError(str(exc)) from exc
