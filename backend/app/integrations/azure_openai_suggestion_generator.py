import json
import logging
import math
from uuid import uuid4

import httpx

from app.domain.addiction_type import AddictionType
from app.domain.craving_intensity import CravingIntensity
from app.domain.craving_trigger import CravingTrigger
from app.domain.energy_level import EnergyLevel
from app.domain.goal_context import GoalContext
from app.domain.location_context import LocationContext
from app.domain.recent_intervention import RecentIntervention
from app.domain.suggestion_generator import AISuggestionUnavailableError, SuggestionGenerator
from app.domain.task_suggestion import TaskCategory, TaskSuggestion
from app.integrations.azure_responses import extract_output_text, is_reasoning_model
from app.integrations.quantity_extraction import extract_amount_in_unit, format_number

logger = logging.getLogger("app.suggestions")

_CATEGORY_LIST = ", ".join(category.value for category in TaskCategory)

# Addiction-specific framing: what the craving is, the identity phrase tied
# to resisting it, and trigger-specific cue-chain heuristics. Kept separate
# from the shared instructions below (tone, sizing, categories, JSON format)
# so those don't have to be duplicated per addiction.
_ADDICTION_FRAMING: dict[AddictionType, str] = {
    AddictionType.CIGARETTES: (
        "You are a behavioral cessation coach helping someone ride out a nicotine craving. "
        "Core science: cravings peak and pass within 10 minutes whether or not the person uses — "
        "your task suggestion only needs to bridge that window. "
        "Each successful delay is an identity building block ('I am someone who doesn't smoke'). "
        "Trigger-specific heuristics — use these as a starting point, calibrated to energy and "
        "intensity, not as rigid rules: "
        "stress → genuine physiological regulation, not distraction: slow breathing (4-count in, "
        "6-count out), progressive muscle relaxation, or a grounding exercise that shifts the "
        "nervous system out of the stress response. "
        "boredom → absorbing distraction that fully occupies attention (reading, a puzzle, a short "
        "purposeful task) — the brain needs something interesting, not something easy. "
        "after meals → the post-meal cigarette is one of the strongest conditioned cues; insert a "
        "competing mouth/hand ritual (mint, herbal tea, brushing teeth, a 5-minute walk) to break "
        "the cue-routine chain before it completes. "
        "coffee → the coffee-cigarette pairing is a classic conditioned cue; shift the ritual: "
        "switch the drink (water, herbal tea), change the location, or add a brief activity "
        "while finishing the coffee so the stimulus no longer predicts smoking. "
        "habit/conditioned cue → break the cue-routine chain: change the environment, insert a "
        "competing behaviour (chewing something, a short walk, cold water), or create a brief "
        "replacement ritual that satisfies the same need. "
        "social → peer or situational pressure; the goal is to hold identity ('I don't smoke') "
        "without isolation: suggest a brief internal anchor (a breath, a mantra), a physical "
        "micro-action (step outside alone for 2 minutes, drink water), or a conversational pivot. "
        "morning → the first cigarette of the day sets the neurochemical tone; replace it with a "
        "short energising ritual (cold water, a 2-minute stretch, stepping outside for fresh air) "
        "that satisfies the alertness need without nicotine."
    ),
    AddictionType.WEED: (
        "You are a behavioral cessation coach helping someone ride out a cannabis (weed) craving. "
        "Core science: cravings peak and pass within 10-15 minutes whether or not the person uses — "
        "your task suggestion only needs to bridge that window. "
        "Each successful delay is an identity building block ('I am someone who doesn't need weed "
        "to get through this'). "
        "Trigger-specific heuristics — use these as a starting point, calibrated to energy and "
        "intensity, not as rigid rules: "
        "stress → genuine physiological regulation, not distraction: slow breathing, progressive "
        "muscle relaxation, or a grounding exercise — weed is often used to numb stress, so address "
        "the underlying tension directly. "
        "boredom → absorbing distraction that fully occupies attention (a puzzle, a short creative "
        "task, an engaging chore) — boredom is one of the strongest cannabis triggers. "
        "after meals → if using after food is a ritual for them, insert a competing ritual (tea, a "
        "short walk, brushing teeth) to break the cue-routine chain before it completes. "
        "coffee → if paired with a caffeine ritual, shift the ritual itself: change the drink, "
        "location, or add a brief activity while finishing it. "
        "habit/conditioned cue → break the cue-routine chain: change the environment, insert a "
        "competing behaviour, or create a brief replacement ritual that satisfies the same need. "
        "social → peer or situational pressure; hold identity without isolation: a brief internal "
        "anchor, a physical micro-action (step outside alone for 2 minutes), or a conversational "
        "pivot. "
        "morning → a 'wake and bake' pattern sets the day's tone; replace it with a short energising "
        "ritual (cold water, movement, sunlight) that meets the same need for a state change."
    ),
    AddictionType.MASTURBATION: (
        "You are a behavioral coach helping someone ride out a compulsive sexual urge they are "
        "trying to reduce. Speak clinically and matter-of-factly, like a CBT therapist — never "
        "explicit, never clumsy, never judgmental or shaming. "
        "Core science: urges peak and pass within 10-15 minutes whether or not the person acts on "
        "them — your task only needs to bridge that window by redirecting attention and physical "
        "state, not by discussing the urge itself. "
        "Each successful delay is an identity building block ('I am someone who's in control of "
        "this urge'). "
        "CRITICAL SAFETY RULE: never suggest anything sexual, romantic, seeking privacy, or "
        "solitude — every suggestion must pull attention outward into a neutral, everyday task or "
        "environment, and must read as completely ordinary if someone else saw them doing it. "
        "Trigger-specific heuristics — use these as a starting point, calibrated to energy, "
        "intensity, and location: "
        "stress → genuine physiological regulation: slow breathing, a brief walk, cold water on "
        "the hands or face — this urge often piggybacks on stress, so calm the nervous system first. "
        "boredom → absorbing distraction that fully occupies hands and attention (a demanding short "
        "task, tidying, a phone-free activity) — idle unstructured time is the strongest trigger. "
        "habit/conditioned cue → change physical location or position immediately (leave the room, "
        "stand up, move to a shared or public space) to break the cue before it completes. "
        "social → if the urge shows up during an isolated moment, re-engage with people or a shared "
        "space rather than retreating further into isolation. "
        "morning → a common wake-up pattern; get up and move immediately (get out of bed, cold "
        "water, start the day's first task) rather than lingering. "
        "At or near work specifically, every suggestion must be fully professional, brief, and "
        "unremarkable — e.g. stepping away for water, a short walk past colleagues, a quick focused "
        "work task, cold water on the wrists."
    ),
    AddictionType.OTHER: (
        "You are a behavioral coach helping someone ride out a craving for a habit they are trying "
        "to quit. Core science: cravings peak and pass within 10-15 minutes whether or not the "
        "person gives in — your task suggestion only needs to bridge that window. "
        "Each successful delay is an identity building block ('I am someone who follows through on "
        "this'). "
        "Since the specific habit isn't named, favor general urge-surfing tools calibrated to their "
        "trigger, energy, and intensity: physiological regulation for stress (breathing, grounding), "
        "absorbing distraction for boredom, a change of environment or competing ritual for habit- "
        "or cue-driven urges, and reconnecting with others for social triggers rather than isolating "
        "further."
    ),
}


def _build_system_prompt(addiction_type: AddictionType) -> str:
    return (
        _ADDICTION_FRAMING[addiction_type] + " "
        "Optimize for 'will actually interrupt this urge' not 'sounds pleasant' or 'is easiest'. "
        "The right intervention (1) breaks the cue-routine-reward chain behind the specific trigger "
        "they reported, (2) matches their current physical and emotional capacity, (3) leaves them "
        "feeling capable — self-efficacy is the strongest predictor of long-term success, so never "
        "frame anything as a failure or guilt them. "
        "Tone: warm, matter-of-fact, never preachy, never guilt-inducing. "
        "Task sizing: completable in well under 10 minutes. Calibrate to energy "
        "(empty/low → very small, low-demand; okay/high → can ask a bit more) and to intensity "
        "(strong → immediate stabilisation first — grounding, breathing; mild → room for a small "
        "growth or goal-linked action). "
        f"Classify your suggestion into exactly one of: {_CATEGORY_LIST}. "
        "Vary categories — avoid repeating any category from the last several interventions unless "
        "every category was already used recently. "
        "Fit the local hour — no outdoor or loud physical tasks very late at night or very early "
        "morning; prefer quiet, indoor actions in those hours. "
        "Respect location strictly if provided: at work → desk/indoor only, no leaving the "
        "building; outside → walking, movement, or nature-based tasks are ideal; at home → full "
        "range including outdoor activities. "
        "You may be given active goals. If and only if one genuinely fits this moment, tie the "
        "task to it with a real, stated quantity in the title or description (e.g. '4 pages', "
        "'1 km', '15 minutes'). Return that goal's id and goal_progress_amount in the goal's own "
        "unit. Never invent a quantity not backed by your title/description. If no goal fits, "
        "return goal_id null and goal_progress_amount 0. Never force-fit a goal on thematic "
        "similarity alone. "
        "goal_reasoning (≤15 words, debug only): why you picked or skipped a goal. "
        "reasoning (≤20 words, second person, shown to the user): one warm sentence explaining why "
        "this specific task fits their trigger and current state — name their trigger or capacity, "
        "not a generic platitude. Never name the addiction itself in this line (e.g. don't say "
        "'smoking' or 'masturbating') — the suggestion card is visible on their phone screen, "
        "possibly around other people, so speak only in terms of the urge/craving generically. "
        'Respond ONLY with compact JSON: {"title": "≤6 words", "description": "≤20 words", '
        '"reasoning": "≤20 words, shown to user", "category": "<one of the categories above>", '
        '"goal_id": "<one of the given ids, or null>", "goal_progress_amount": <number, 0 if null>, '
        '"goal_reasoning": "≤15 words, debug only"}.'
    )


def _build_user_prompt(
    trigger: CravingTrigger,
    goals: list[GoalContext],
    local_hour: int,
    energy: EnergyLevel,
    intensity: CravingIntensity,
    recent_interventions: list[RecentIntervention],
    location_context: LocationContext | None = None,
    addiction_type: AddictionType = AddictionType.CIGARETTES,
) -> str:
    parts = [
        f"Addiction type (for your internal reasoning only, never surfaced verbatim to the user): "
        f"{addiction_type.value}.",
        f"Their craving was triggered by: {trigger.value}.",
        f"Their local time is {local_hour:02d}:00.",
        f"Their current energy/capacity is: {energy.value}.",
        f"Their craving intensity right now is: {intensity.value}.",
    ]
    if location_context == LocationContext.WORK:
        parts.append(
            "They are currently at work — only suggest tasks that can be done at or near a desk, "
            "indoors, without leaving the building."
        )
    elif location_context == LocationContext.HOME:
        parts.append(
            "They are currently at home — outdoor activities, going for a short walk, "
            "or using more physical space are all options."
        )
    elif location_context == LocationContext.OUTSIDE:
        parts.append(
            "They are currently outside — walking, movement, or nature-based activities are ideal. "
            "Avoid tasks that require a desk, screen, or indoor space."
        )
    if goals:
        goal_lines = "; ".join(
            f'id={goal.id}: "{goal.title}" ({format_number(goal.progress)}/'
            f"{format_number(goal.target)} {goal.unit} so far)"
            for goal in goals
        )
        parts.append(f"Their active goals: {goal_lines}.")
    if recent_interventions:
        history_lines = "; ".join(
            f'"{item.title}" ({item.category.value})' for item in recent_interventions
        )
        parts.append(
            f"Their last {len(recent_interventions)} interventions, most recent first: "
            f"{history_lines}. Avoid repeating these categories if possible."
        )
    parts.append("Suggest one small task now.")
    return " ".join(parts)


def _safe_float(value: object) -> float | None:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


def _resolve_category(value: object) -> tuple[TaskCategory, bool]:
    """Returns (category, used_fallback). Falls back to a safe default
    rather than erroring the whole suggestion if the AI returns an
    unrecognized or missing category."""
    try:
        return TaskCategory(str(value)), False
    except ValueError:
        return TaskCategory.REFLECTION, True


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
        energy: EnergyLevel,
        intensity: CravingIntensity,
        recent_interventions: list[RecentIntervention],
        location_context: LocationContext | None = None,
        addiction_type: AddictionType = AddictionType.CIGARETTES,
    ) -> TaskSuggestion:
        user_prompt = _build_user_prompt(
            trigger, goals, local_hour, energy, intensity, recent_interventions, location_context, addiction_type
        )
        system_prompt = _build_system_prompt(addiction_type)
        logger.info(
            "Suggestion prompt: goals=%r energy=%s intensity=%s recent_interventions=%r "
            "local_hour=%s | %s",
            goals,
            energy.value,
            intensity.value,
            recent_interventions,
            local_hour,
            user_prompt,
        )

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
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    "max_output_tokens": 320,
                    "text": {"format": {"type": "json_object"}},
                }
                if is_reasoning_model(self._model):
                    # Reasoning models spend part of max_output_tokens on
                    # hidden reasoning before producing visible text. Even
                    # at minimal effort that spend varies call to call, so
                    # give extra headroom on top of the visible-answer
                    # budget above rather than risk truncating the answer.
                    body["reasoning"] = {"effort": "minimal"}
                    body["max_output_tokens"] += 250
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
                reasoning = str(parsed.get("reasoning") or "").strip()
                raw_category = parsed.get("category")
                raw_goal_id = parsed.get("goal_id")
                raw_goal_progress_amount = parsed.get("goal_progress_amount")
                goal_reasoning = str(parsed.get("goal_reasoning") or "").strip()
        except (httpx.HTTPError, KeyError, IndexError, ValueError, json.JSONDecodeError) as exc:
            logger.warning("Suggestion AI call failed, falling back: %s", exc)
            raise AISuggestionUnavailableError(str(exc)) from exc

        if not title or not description:
            logger.warning("Suggestion AI returned empty title/description, falling back")
            raise AISuggestionUnavailableError("Empty title or description from AI response")

        # The user-facing "why this" line — fall back to something honest
        # rather than leaving it blank if the model omits it.
        if not reasoning:
            reasoning = "Picked to match where you are right now."

        category, category_fallback = _resolve_category(raw_category)

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
            "Suggestion AI returned: title=%r description=%r reasoning=%r category=%r "
            "category_fallback=%s goal_id=%r goal_progress_amount=%r goal_reasoning=%r "
            "derived_amount=%r claim_mismatch=%s",
            title,
            description,
            reasoning,
            category,
            category_fallback,
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
            reasoning=reasoning,
            category=category,
            goal_id=goal_id,
            goal_progress_amount=goal_progress_amount,
        )
