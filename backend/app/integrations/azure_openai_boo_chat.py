import httpx

from app.integrations.azure_responses import extract_output_text, is_reasoning_model
from app.integrations.supabase_admin_client import ConversationTurn, GoalProgress, RecentSession

# Distilled from docs/boo.md — Boo's persona, principles, and response
# guidelines for "Boo Conversations": an always-available companion, not
# a general-purpose assistant, whose job is to help the user make better
# decisions in the moments that matter (cravings, relapse, planning,
# reflection, general support).
_SYSTEM_PROMPT = (
    "You are Boo — an always-available companion inside Telegram helping someone build the "
    "identity and habits of a person who doesn't give in to their addiction. You are not a "
    "general-purpose assistant; every reply should move them one small step closer to who "
    "they're trying to become. "
    "Personality: calm, confident, observant, supportive, honest, slightly witty, emotionally "
    "intelligent. Never sound like a therapist, a motivational speaker, a productivity guru, "
    "or customer support. "
    "Style: short, conversational, direct, warm, actionable. Prefer asking ONE meaningful "
    "question over long explanations. Avoid unnecessary emojis. Avoid generic encouragement "
    "and motivational quotes. One excellent suggestion beats five average ones — don't list "
    "options. "
    "Core principles: "
    "(1) Progress over perfection — never judge failures, help them learn from it instead. "
    "(2) Small actions beat big advice — whenever possible guide them toward something "
    "completable in a few minutes, not a speech. "
    "(3) Understand before solving — before advising, know what happened, why, how they "
    "feel, and what they actually need; ask a follow-up question when it's not clear yet. "
    "(4) Build identity, not just outcomes — reinforce who they're becoming rather than just "
    "praising the result (e.g. not 'you avoided smoking' but 'you acted like someone who "
    "doesn't automatically obey cravings'). "
    "(5) Feel natural — you're not running a script; you're a thoughtful friend who "
    "genuinely remembers what's been said before. Use the conversation history and context "
    "you're given naturally, without ever explicitly listing it back at them. "
    "Classify the message's intent first (craving, relapse, success, planning, reflection, "
    "general support, or something else) and let that shape your response: "
    "craving → slow them down, identify the trigger, redirect to one meaningful action, "
    "offer to follow up. "
    "relapse → remove shame entirely, understand the trigger, help them learn, prepare for "
    "next time — never punish or guilt-trip. "
    "success → celebrate appropriately, reinforce identity, keep momentum — don't undersell "
    "it, but don't gush either. "
    "planning → keep it realistic, help them find the one thing that would make today feel "
    "worthwhile, don't overload them. "
    "reflection → help them process and notice patterns, mostly by listening and asking, not "
    "solving. "
    "Never: shame them, lecture them, overwhelm them, give generic motivational quotes, "
    "ignore the conversation history, pretend to remember something that isn't in the "
    "context you were given, or make them feel guilty for relapsing. "
    "A good reply usually acknowledges what they said, shows you understood the situation, "
    "and points to one concrete next step — optionally with one follow-up question. Keep "
    "replies short (usually 1-4 short lines, rarely more). "
    "Respond with ONLY Boo's reply text — no labels, no preamble, no explanation of your "
    "reasoning."
)


class BooChatUnavailableError(Exception):
    pass


class BooChatContentFilteredError(BooChatUnavailableError):
    """Azure's platform-level content filter rejected the prompt before
    the model ever saw it — not a transient failure, so callers should
    ask the user to rephrase rather than imply something's broken."""

    pass


def _format_context(
    *,
    display_name: str | None,
    day_part: str,
    days_clean: int | None,
    target: int | None,
    quit_reasons: list[str],
    goals: list[GoalProgress],
    recent_sessions: list[RecentSession],
) -> str:
    parts = [f"Current context — it's {day_part} for them."]
    parts.append(f"Name: {display_name}." if display_name else "Name: unknown.")

    if days_clean is None:
        parts.append("No days-clean data available.")
    else:
        target_line = f", target {target} days" if target else ""
        parts.append(f"Days clean: {days_clean}{target_line}.")

    if quit_reasons:
        parts.append(f"Reasons for quitting: {', '.join(quit_reasons)}.")

    if goals:
        goal_lines = "; ".join(
            f'"{goal.title}" ({goal.progress:g}/{goal.target:g} {goal.unit})' for goal in goals
        )
        parts.append(f"Active goals this month: {goal_lines}.")
    else:
        parts.append("No active goals this month.")

    if recent_sessions:
        session_lines = "; ".join(
            f"{session.outcome or 'unknown'} (trigger: {session.trigger or 'unknown'}, "
            f"{session.addiction_type or 'unknown'})"
            for session in recent_sessions
        )
        parts.append(f"Recent craving sessions, most recent first: {session_lines}.")

    return " ".join(parts)


class AzureOpenAIBooChat:
    def __init__(
        self,
        endpoint: str,
        api_key: str,
        model: str = "gpt-4o-mini",
        timeout_seconds: float = 15.0,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._endpoint = endpoint
        self._api_key = api_key
        self._model = model
        self._timeout_seconds = timeout_seconds
        self._transport = transport  # overridable in tests; None uses the real network

    async def reply(
        self,
        *,
        display_name: str | None,
        day_part: str,
        days_clean: int | None,
        target: int | None,
        quit_reasons: list[str],
        goals: list[GoalProgress],
        recent_sessions: list[RecentSession],
        history: list[ConversationTurn],
        message: str,
    ) -> str:
        context_line = _format_context(
            display_name=display_name,
            day_part=day_part,
            days_clean=days_clean,
            target=target,
            quit_reasons=quit_reasons,
            goals=goals,
            recent_sessions=recent_sessions,
        )

        input_messages = [{"role": "system", "content": f"{_SYSTEM_PROMPT}\n\n{context_line}"}]
        for turn in history:
            role = "assistant" if turn.role == "assistant" else "user"
            input_messages.append({"role": role, "content": turn.content})
        input_messages.append({"role": "user", "content": message})

        try:
            async with httpx.AsyncClient(
                timeout=self._timeout_seconds, transport=self._transport
            ) as client:
                body = {
                    "model": self._model,
                    "input": input_messages,
                    "max_output_tokens": 300,
                }
                if is_reasoning_model(self._model):
                    body["reasoning"] = {"effort": "minimal"}
                    body["max_output_tokens"] += 200
                response = await client.post(
                    self._endpoint,
                    headers={"api-key": self._api_key, "Content-Type": "application/json"},
                    json=body,
                )
                if response.status_code == 400:
                    error_code = None
                    try:
                        error_code = response.json().get("error", {}).get("code")
                    except ValueError:
                        pass
                    if error_code == "content_filter":
                        raise BooChatContentFilteredError("Prompt blocked by Azure content filter")
                response.raise_for_status()
                text = extract_output_text(response.json()).strip()
        except (httpx.HTTPError, KeyError, IndexError, ValueError) as exc:
            raise BooChatUnavailableError(str(exc)) from exc

        if not text:
            raise BooChatUnavailableError("Empty reply from AI response")
        return text
