import httpx

from app.integrations.azure_responses import extract_output_text, is_reasoning_model

_SYSTEM_PROMPT = (
    "You write a single short daily check-in message for someone tracking their progress "
    "staying clean from an addiction, sent as a phone notification. Tone: warm and human, "
    "like a close friend who's genuinely rooting for them — never clinical, never "
    "guilt-inducing, never over-the-top motivational-poster energy. "
    "Vary your wording, structure, and opening every time — never fall into a fixed "
    "template like always starting with 'Day X'; sometimes lead with the feeling, "
    "sometimes with the number, sometimes with a question or a small observation. "
    "Reference their actual day count naturally when given, and their target if given, "
    "but don't force both into the same sentence shape every time. "
    "If no day count is given, write a short generic-but-warm encouragement instead — "
    "never invent a number. "
    "Keep it to 1-2 short sentences (under ~35 words total). Light emoji is welcome but "
    "optional — don't overdo it. Sign off as Boo only occasionally, not every message. "
    "Respond with ONLY the message text — no quotes, no preamble, no explanation."
)


class ReminderMessageUnavailableError(Exception):
    pass


class AzureOpenAIReminderGenerator:
    def __init__(
        self,
        endpoint: str,
        api_key: str,
        model: str = "gpt-4o-mini",
        timeout_seconds: float = 8.0,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._endpoint = endpoint
        self._api_key = api_key
        self._model = model
        self._timeout_seconds = timeout_seconds
        self._transport = transport  # overridable in tests; None uses the real network

    async def generate(self, days_clean: int | None, target: int | None) -> str:
        if days_clean is None:
            user_prompt = "No day-count data is available for this person right now."
        else:
            user_prompt = f"Days clean: {days_clean}."
            user_prompt += f" Target: {target} days." if target else " No specific target set."

        try:
            async with httpx.AsyncClient(
                timeout=self._timeout_seconds, transport=self._transport
            ) as client:
                body = {
                    "model": self._model,
                    "input": [
                        {"role": "system", "content": _SYSTEM_PROMPT},
                        {"role": "user", "content": user_prompt},
                    ],
                    "max_output_tokens": 120,
                }
                if is_reasoning_model(self._model):
                    body["reasoning"] = {"effort": "minimal"}
                    body["max_output_tokens"] += 150
                response = await client.post(
                    self._endpoint,
                    headers={"api-key": self._api_key, "Content-Type": "application/json"},
                    json=body,
                )
                response.raise_for_status()
                text = extract_output_text(response.json()).strip()
        except (httpx.HTTPError, KeyError, IndexError, ValueError) as exc:
            raise ReminderMessageUnavailableError(str(exc)) from exc

        if not text:
            raise ReminderMessageUnavailableError("Empty message from AI response")
        return text
