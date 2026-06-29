import json
import logging
import math
from uuid import uuid4

import httpx

from app.domain.craving_trigger import CravingTrigger
from app.domain.goal_context import GoalContext
from app.domain.suggestion_generator import AISuggestionUnavailableError, SuggestionGenerator
from app.domain.task_suggestion import TaskCategory, TaskSuggestion
from app.integrations.azure_responses import extract_output_text, is_reasoning_model
from app.integrations.quantity_extraction import extract_amount_in_unit, format_number

logger = logging.getLogger("app.suggestions")

_SYSTEM_PROMPT = (
    "You suggest one small, calming action for someone delaying a craving for 20 minutes. "
    "Tone: warm, non-judgmental, never preachy, never guilt-inducing. The action must take "
    "well under 20 minutes, and must fit their current local hour — avoid suggesting "
    "jogging, loud exercise, or going outside very late at night or very early morning; "
    "prefer quiet, indoor actions then. If told what was suggested last time, suggest "
    "something noticeably different in kind. You may be given a list of the person's active "
    "goals, each with an id and a unit (e.g. km, pages, hours, sessions). If — and only if — "
    "one of them genuinely fits this exact moment, make the suggestion contribute to it: state "
    "a real, concrete quantity with its own natural unit somewhere in your title or description "
    '(e.g. "15 minutes", "4 pages", "1 km", "one session") — use whatever unit honestly '
    "describes the activity, not necessarily the goal's own unit; the app converts between "
    "compatible units (e.g. minutes into hours). Then return that goal's id, and your own best "
    "estimate of goal_progress_amount expressed in the goal's own unit. Never invent a quantity "
    "that isn't backed by what your title/description actually says. If no goal genuinely fits, "
    "return goal_id as null and goal_progress_amount as 0. Never force-fit a goal just because "
    "the activity is thematically similar — it must actually earn a truthful, stated quantity. "
    "Also state in goal_reasoning, in well under 15 words, why you picked that goal (or why none "
    "fit) — this is shown to the developer for debugging, not the end user. Respond ONLY with "
    'compact JSON: {"title": "<=6 words", "description": "<=20 words", "goal_id": "<one of the '
    'given ids, or null>", "goal_progress_amount": <number, 0 if goal_id is null>, '
    '"goal_reasoning": "<=15 words"}.'
)


def _build_user_prompt(
    trigger: CravingTrigger,
    goals: list[GoalContext],
    local_hour: int,
    last_suggestion_title: str | None,
) -> str:
    parts = [
        f"Their craving was triggered by: {trigger.value}.",
        f"Their local time is {local_hour:02d}:00.",
    ]
    if goals:
        goal_lines = "; ".join(
            f'id={goal.id}: "{goal.title}" ({format_number(goal.progress)}/'
            f"{format_number(goal.target)} {goal.unit} so far)"
            for goal in goals
        )
        parts.append(f"Their active goals: {goal_lines}.")
    if last_suggestion_title:
        parts.append(
            f'Last time they were suggested: "{last_suggestion_title}". Suggest something '
            "different in kind this time."
        )
    parts.append("Suggest one small task now.")
    return " ".join(parts)


def _safe_float(value: object) -> float | None:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


class AzureOpenAISuggestionGenerator(SuggestionGenerator):
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
        trigger: CravingTrigger,
        goals: list[GoalContext],
        local_hour: int,
        last_suggestion_title: str | None,
    ) -> TaskSuggestion:
        user_prompt = _build_user_prompt(trigger, goals, local_hour, last_suggestion_title)
        logger.info("Suggestion prompt: goals=%r local_hour=%s | %s", goals, local_hour, user_prompt)

        try:
            async with httpx.AsyncClient(
                timeout=self._timeout_seconds, transport=self._transport
            ) as client:
                # Azure's Responses API: deployment/model goes in the body
                # (not the URL), and the reply is nested under
                # output[0].content[0].text rather than choices[0].message.
                body = {
                    "model": self._model,
                    "input": [
                        {"role": "system", "content": _SYSTEM_PROMPT},
                        {"role": "user", "content": user_prompt},
                    ],
                    "max_output_tokens": 200,
                    "text": {"format": {"type": "json_object"}},
                }
                if is_reasoning_model(self._model):
                    # Reasoning models spend part of max_output_tokens on
                    # hidden reasoning before producing visible text. Even
                    # at minimal effort that spend varies call to call, so
                    # give extra headroom on top of the visible-answer
                    # budget above rather than risk truncating the answer.
                    body["reasoning"] = {"effort": "minimal"}
                    body["max_output_tokens"] += 150
                response = await client.post(
                    self._endpoint,
                    headers={"api-key": self._api_key, "Content-Type": "application/json"},
                    json=body,
                )
                response.raise_for_status()
                content = extract_output_text(response.json())
                parsed = json.loads(content)
                title = str(parsed["title"]).strip()
                description = str(parsed["description"]).strip()
                raw_goal_id = parsed.get("goal_id")
                raw_goal_progress_amount = parsed.get("goal_progress_amount")
                goal_reasoning = str(parsed.get("goal_reasoning") or "").strip()
        except (httpx.HTTPError, KeyError, IndexError, ValueError, json.JSONDecodeError) as exc:
            logger.warning("Suggestion AI call failed, falling back: %s", exc)
            raise AISuggestionUnavailableError(str(exc)) from exc

        if not title or not description:
            logger.warning("Suggestion AI returned empty title/description, falling back")
            raise AISuggestionUnavailableError("Empty title or description from AI response")

        goals_by_id = {goal.id: goal for goal in goals}
        goal_id = str(raw_goal_id).strip() if raw_goal_id else None
        if goal_id not in goals_by_id:
            goal_id = None

        # The AI doesn't always state an honest, derivable quantity even
        # when asked to — derive the actual credited amount from the
        # task's own title/description instead of trusting
        # goal_progress_amount blindly. This is also how any unit (hours,
        # sessions, days, ...) becomes eligible: there's no hardcoded list
        # of forbidden units, just a requirement that the task's text
        # actually states a quantity that resolves to this goal's unit.
        derived_amount = None
        if goal_id is not None:
            derived_amount = extract_amount_in_unit(f"{title} {description}", goals_by_id[goal_id].unit)
            if derived_amount is None or derived_amount <= 0:
                goal_id = None

        # Cross-check: if the AI's own claimed amount meaningfully
        # contradicts what its task text actually states, something is
        # inconsistent (e.g. a hallucinated justification) — don't trust
        # either number.
        claim_mismatch = False
        if goal_id is not None:
            claimed = _safe_float(raw_goal_progress_amount)
            if claimed is not None and not math.isclose(
                claimed, derived_amount, rel_tol=0.1, abs_tol=0.05
            ):
                claim_mismatch = True
                goal_id = None

        goal_progress_amount = 0.0
        if goal_id is not None:
            remaining = max(goals_by_id[goal_id].target - goals_by_id[goal_id].progress, 0)
            goal_progress_amount = min(derived_amount, remaining) if remaining > 0 else 0.0
            if goal_progress_amount <= 0:
                goal_id = None

        logger.info(
            "Suggestion AI returned: title=%r description=%r goal_id=%r goal_progress_amount=%r "
            "goal_reasoning=%r derived_amount=%r claim_mismatch=%s",
            title,
            description,
            goal_id,
            goal_progress_amount,
            goal_reasoning,
            derived_amount,
            claim_mismatch,
        )
        return TaskSuggestion(
            id=f"ai:{uuid4()}",
            title=title,
            description=description,
            category=TaskCategory.PRODUCTIVITY,
            goal_id=goal_id,
            goal_progress_amount=goal_progress_amount,
        )
