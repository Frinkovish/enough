import json
import logging
from uuid import uuid4

import httpx

from app.domain.craving_trigger import CravingTrigger
from app.domain.goal_context import GoalContext
from app.domain.suggestion_generator import AISuggestionUnavailableError, SuggestionGenerator
from app.domain.task_suggestion import TaskCategory, TaskSuggestion
from app.integrations.azure_responses import extract_output_text, is_reasoning_model

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
    'title says "Read 5 pages", goal_progress_amount must be 5). Be honest about scale: a task '
    "that fits in well under 20 minutes can only honestly represent a small slice of a "
    "coarse-grained goal — never claim a whole 'hour' or a whole 'session' for a couple of "
    "minutes of activity. If the goal's unit is something a brief task cannot truthfully earn "
    "a nonzero whole-number amount of (e.g. 'hours' for a study goal, 'sessions' for a goal "
    "needing a dedicated occasion like a workout class or a match), leave that goal alone. If "
    "no goal fits, return goal_id as null and goal_progress_amount as 0. Never force-fit a goal "
    "that doesn't make sense right now (e.g. don't pick a running goal at 4am, and don't pick a "
    "goal just because the activity is thematically similar — it must actually earn a truthful "
    "quantity). Also state in goal_reasoning, in well under 15 words, why you picked that goal "
    "(or why none fit) — this is shown to the developer for debugging, not the end user. "
    "Respond ONLY with compact JSON: "
    '{"title": "<=6 words", "description": "<=20 words", "goal_id": "<one of the given ids, or '
    'null>", "goal_progress_amount": <integer, 0 if goal_id is null>, "goal_reasoning": '
    '"<=15 words"}.'
)

# Units a sub-20-minute task can never honestly earn a whole unit of —
# enforced in code since the AI doesn't always follow the prompt's
# instruction not to claim these (see _SYSTEM_PROMPT).
_UNCOUNTABLE_UNITS = {
    "hour",
    "hours",
    "session",
    "sessions",
    "class",
    "classes",
    "workout",
    "workouts",
    "day",
    "days",
}


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

        # The AI is asked not to claim a whole "hour" or "session" for a
        # sub-20-minute task (see _SYSTEM_PROMPT), but it doesn't always
        # comply — enforce it here so a quick task can never be miscredited
        # as a full unit of a coarse-grained goal like "5 hours" or
        # "8 sessions".
        blocked_uncountable_goal = (
            goal_id is not None and goals_by_id[goal_id].unit.strip().lower() in _UNCOUNTABLE_UNITS
        )
        if blocked_uncountable_goal:
            goal_id = None

        # The AI sometimes credits a goal that has nothing to do with the
        # task it just wrote (e.g. a muscle-relaxation exercise credited
        # as "reading pages", with a reasoning string that doesn't match
        # the title at all). Require the goal's own unit to actually be
        # mentioned in the task's title/description as a sanity check —
        # if the task doesn't talk about pages/km/etc., it isn't earning
        # progress in that unit.
        blocked_unit_not_mentioned = False
        if goal_id is not None:
            unit = goals_by_id[goal_id].unit.strip().lower()
            haystack = f"{title} {description}".lower()
            mentions_unit = bool(unit) and (unit in haystack or unit.rstrip("s") in haystack)
            if not mentions_unit:
                blocked_unit_not_mentioned = True
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
            "Suggestion AI returned: title=%r description=%r goal_id=%r goal_progress_amount=%r "
            "goal_reasoning=%r blocked_uncountable_goal=%s blocked_unit_not_mentioned=%s",
            title,
            description,
            goal_id,
            goal_progress_amount,
            goal_reasoning,
            blocked_uncountable_goal,
            blocked_unit_not_mentioned,
        )
        return TaskSuggestion(
            id=f"ai:{uuid4()}",
            title=title,
            description=description,
            category=TaskCategory.PRODUCTIVITY,
            goal_id=goal_id,
            goal_progress_amount=goal_progress_amount,
        )
