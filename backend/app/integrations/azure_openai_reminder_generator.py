import httpx

from app.integrations.azure_responses import extract_output_text, is_reasoning_model
from app.integrations.supabase_admin_client import GoalProgress

_SYSTEM_PROMPT = (
    "You write a single short daily check-in message for someone tracking their progress "
    "staying clean from an addiction, sent as a phone notification. Tone: warm and human, "
    "like a close friend who's genuinely rooting for them — never clinical, never "
    "guilt-inducing, never over-the-top motivational-poster energy, never a listicle. "
    "You'll be given several pieces of context below — do NOT try to mention all of them "
    "in one message. Pick ONE, or at most two, that feel most worth saying right now, and "
    "ignore the rest. Rotate what you focus on across messages over time (sometimes the day "
    "count, sometimes a goal, sometimes their reason for quitting, sometimes just an "
    "authentic observation about the time of day) so it never reads like a checklist or a "
    "fixed template. Never fall into always starting with 'Day X' or always using the "
    "person's name in the same spot. "
    "Use their name only if given, and only sometimes — not every message. "
    "Reference the time of day naturally if it fits, without a generic 'good morning' "
    "greeting every time. "
    "If a goal is mentioned, refer to it in passing, specific but brief (e.g. what they're "
    "at vs. the target) — don't turn it into a status report. "
    "If a quit-reason is mentioned, use it to genuinely remind them why this matters, not as "
    "a guilt trip. "
    "If no day-count/goal/reason data is given for a category, don't invent one — just work "
    "with what you have, or default to a short generic-but-warm encouragement. "
    "Keep it to 1-2 short sentences (under ~35 words total). Light emoji is welcome but "
    "optional — don't overdo it. Sign off as Boo only occasionally, not every message. "
    "Respond with ONLY the message text — no quotes, no preamble, no explanation."
)


class ReminderMessageUnavailableError(Exception):
    pass


def _build_user_prompt(
    *,
    display_name: str | None,
    day_part: str,
    days_clean: int | None,
    target: int | None,
    quit_reasons: list[str],
    goals: list[GoalProgress],
) -> str:
    parts = [f"It's currently {day_part} for them."]
    parts.append(f"Their name is {display_name}." if display_name else "Their name isn't known.")

    if days_clean is None:
        parts.append("No day-count data is available.")
    else:
        parts.append(f"They've been clean for {days_clean} days.")
        parts.append(f"Their personal target is {target} days." if target else "They haven't set a target.")

    if quit_reasons:
        parts.append(f"Their reasons for quitting: {', '.join(quit_reasons)}.")

    if goals:
        goal_lines = "; ".join(
            f'"{goal.title}" ({goal.progress:g}/{goal.target:g} {goal.unit})' for goal in goals
        )
        parts.append(f"Their in-progress goals this month: {goal_lines}.")
    else:
        parts.append("No active goals this month.")

    parts.append("Write one message now.")
    return " ".join(parts)


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

    async def generate(
        self,
        *,
        display_name: str | None,
        day_part: str,
        days_clean: int | None,
        target: int | None,
        quit_reasons: list[str],
        goals: list[GoalProgress],
    ) -> str:
        user_prompt = _build_user_prompt(
            display_name=display_name,
            day_part=day_part,
            days_clean=days_clean,
            target=target,
            quit_reasons=quit_reasons,
            goals=goals,
        )

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
