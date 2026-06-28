import json
import logging
from uuid import uuid4

import httpx

from app.domain.craving_trigger import CravingTrigger
from app.domain.goal_context import GoalContext
from app.domain.suggestion_generator import AISuggestionUnavailableError, SuggestionGenerator
from app.domain.task_suggestion import TaskCategory, TaskSuggestion

logger = logging.getLogger("app.suggestions")

_SYSTEM_PROMPT = (
    "You suggest one small, calming action for someone delaying a craving for 20 minutes. "
    "Tone: warm, non-judgmental, never preachy, never guilt-inducing. The action must take "
    "well under 20 minutes, and must fit their current local hour — avoid suggesting "
    "jogging, loud exercise, or going outside very late at night or very early morning; "
    "prefer quiet, indoor actions then. If told what was suggested last time, suggest "
    "something noticeably different in kind. You may be given a list of the person's active "
    "goals, each with an id and a unit (e.g. km, pages, hours). If — and only if — one of them "
    "genuinely fits this exact moment, make the suggestion contribute to it: return that goal's "
    "id, and state in goal_progress_amount exactly how many of its units the task represents — "
    "this number MUST match the quantity stated in your own title/description (e.g. if your "
    'title says "Read 5 pages", goal_progress_amount must be 5). If no goal fits, return '
    'goal_id as null and goal_progress_amount as 0. Never force-fit a goal that doesn\'t make '
    'sense right now (e.g. don\'t pick a running goal at 4am). Respond ONLY with compact JSON: '
    '{"title": "<=6 words", "description": "<=20 words", "goal_id": "<one of the given ids, or '
    'null>", "goal_progress_amount": <integer, 0 if goal_id is null>}.'
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
            f'id={goal.id}: "{goal.title}" ({goal.progress}/{goal.target} {goal.unit} so far)'
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
                response = await client.post(
                    self._endpoint,
                    headers={"api-key": self._api_key, "Content-Type": "application/json"},
                    json={
                        "model": self._model,
                        "input": [
                            {"role": "system", "content": _SYSTEM_PROMPT},
                            {"role": "user", "content": user_prompt},
                        ],
                        "max_output_tokens": 150,
                        "temperature": 0.8,
                        "text": {"format": {"type": "json_object"}},
                    },
                )
                response.raise_for_status()
                content = response.json()["output"][0]["content"][0]["text"]
                parsed = json.loads(content)
                title = str(parsed["title"]).strip()
                description = str(parsed["description"]).strip()
                raw_goal_id = parsed.get("goal_id")
                raw_goal_progress_amount = parsed.get("goal_progress_amount")
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

        goal_progress_amount = 0
        if goal_id is not None:
            try:
                goal_progress_amount = int(raw_goal_progress_amount)
            except (TypeError, ValueError):
                goal_progress_amount = 1
            if goal_progress_amount < 1:
                goal_progress_amount = 1
            remaining = max(goals_by_id[goal_id].target - goals_by_id[goal_id].progress, 0)
            goal_progress_amount = min(goal_progress_amount, remaining) if remaining > 0 else 0
            if goal_progress_amount == 0:
                goal_id = None

        logger.info(
            "Suggestion AI returned: title=%r description=%r goal_id=%r goal_progress_amount=%r",
            title,
            description,
            goal_id,
            goal_progress_amount,
        )
        return TaskSuggestion(
            id=f"ai:{uuid4()}",
            title=title,
            description=description,
            category=TaskCategory.PRODUCTIVITY,
            goal_id=goal_id,
            goal_progress_amount=goal_progress_amount,
        )
