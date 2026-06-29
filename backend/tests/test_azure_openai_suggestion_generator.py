import json

import httpx
import pytest

from app.domain.craving_trigger import CravingTrigger
from app.domain.goal_context import GoalContext
from app.domain.suggestion_generator import AISuggestionUnavailableError
from app.integrations.azure_openai_suggestion_generator import AzureOpenAISuggestionGenerator


def _responses_payload(content: str) -> dict:
    return {"output": [{"type": "message", "content": [{"type": "output_text", "text": content}]}]}


def _transport_returning(payload: dict, status_code: int = 200) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code, json=payload)

    return httpx.MockTransport(handler)


async def test_generate_returns_parsed_suggestion() -> None:
    transport = _transport_returning(
        _responses_payload(json.dumps({"title": "Stretch", "description": "Two minutes, slow."}))
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    suggestion = await generator.generate(CravingTrigger.STRESS, [], 14, None)

    assert suggestion.title == "Stretch"
    assert suggestion.description == "Two minutes, slow."
    assert suggestion.id.startswith("ai:")
    assert suggestion.goal_id is None


async def test_generate_raises_on_http_error() -> None:
    transport = _transport_returning({"error": "boom"}, status_code=500)
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    with pytest.raises(AISuggestionUnavailableError):
        await generator.generate(CravingTrigger.STRESS, [], 14, None)


async def test_generate_raises_on_malformed_json_content() -> None:
    transport = _transport_returning(_responses_payload("not json"))
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    with pytest.raises(AISuggestionUnavailableError):
        await generator.generate(CravingTrigger.STRESS, [], 14, None)


async def test_generate_raises_on_empty_fields() -> None:
    transport = _transport_returning(
        _responses_payload(json.dumps({"title": "", "description": ""}))
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    with pytest.raises(AISuggestionUnavailableError):
        await generator.generate(CravingTrigger.STRESS, [], 14, None)


async def test_generate_raises_when_output_is_empty() -> None:
    transport = _transport_returning({"output": []})
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    with pytest.raises(AISuggestionUnavailableError):
        await generator.generate(CravingTrigger.STRESS, [], 14, None)


async def test_generate_includes_goal_list_in_prompt_and_returns_chosen_goal_id() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json=_responses_payload(
                json.dumps(
                    {
                        "title": "Run 1 km",
                        "description": "Easy pace.",
                        "goal_id": "run-goal",
                        "goal_progress_amount": 1,
                    }
                )
            ),
        )

    transport = httpx.MockTransport(handler)
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [
        GoalContext(id="run-goal", title="Run", target=5, unit="km", progress=2),
        GoalContext(id="read-goal", title="Read", target=1, unit="book", progress=0),
    ]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    user_message = captured["body"]["input"][1]["content"]
    assert "Run" in user_message
    assert "Read" in user_message
    assert "2/5 km" in user_message
    assert captured["body"]["model"] == "gpt-4o-mini"
    assert suggestion.goal_id == "run-goal"
    assert suggestion.goal_progress_amount == 1


async def test_generate_uses_ai_stated_goal_progress_amount() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Read 5 pages quietly",
                    "description": "Pick up your book.",
                    "goal_id": "read-goal",
                    "goal_progress_amount": 5,
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="read-goal", title="Read", target=300, unit="pages", progress=0)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    assert suggestion.goal_id == "read-goal"
    assert suggestion.goal_progress_amount == 5


async def test_generate_clamps_goal_progress_amount_to_remaining() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Read 10 pages",
                    "description": "Finish the chapter.",
                    "goal_id": "read-goal",
                    "goal_progress_amount": 10,
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="read-goal", title="Read", target=300, unit="pages", progress=295)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    assert suggestion.goal_progress_amount == 5


async def test_generate_derives_goal_progress_amount_from_text_when_claim_missing() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps({"title": "Run 1 km", "description": "Easy pace.", "goal_id": "run-goal"})
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="run-goal", title="Run", target=5, unit="km", progress=0)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    assert suggestion.goal_id == "run-goal"
    assert suggestion.goal_progress_amount == 1


async def test_generate_converts_minutes_to_hours_for_an_hours_goal() -> None:
    """Any unit is eligible as long as the task text states a quantity
    that converts to it — no hardcoded list of forbidden units."""
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Study DBT flashcards",
                    "description": "Review for 15 minutes, no pressure.",
                    "goal_id": "dbt-goal",
                    "goal_progress_amount": 0.25,
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="dbt-goal", title="Learn DBT", target=5, unit="hours", progress=1)]

    suggestion = await generator.generate(CravingTrigger.STRESS, goals, 16, None)

    assert suggestion.goal_id == "dbt-goal"
    assert suggestion.goal_progress_amount == 0.25


async def test_generate_credits_a_spelled_out_session_count() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Padel serve drill",
                    "description": "Practice padel serves for one session.",
                    "goal_id": "padel-goal",
                    "goal_progress_amount": 1,
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="padel-goal", title="Padel Practice", target=8, unit="sessions", progress=0)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 16, None)

    assert suggestion.goal_id == "padel-goal"
    assert suggestion.goal_progress_amount == 1


async def test_generate_blocks_credit_when_claimed_amount_contradicts_task_text() -> None:
    """If the AI's claimed goal_progress_amount disagrees with what its
    own title/description actually states, trust neither number."""
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Study DBT flashcards",
                    "description": "Review for 15 minutes, no pressure.",
                    "goal_id": "dbt-goal",
                    "goal_progress_amount": 1,  # claims a whole hour, text says 15 minutes
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="dbt-goal", title="Learn DBT", target=5, unit="hours", progress=0)]

    suggestion = await generator.generate(CravingTrigger.STRESS, goals, 16, None)

    assert suggestion.goal_id is None
    assert suggestion.goal_progress_amount == 0


async def test_generate_does_not_credit_goal_when_no_quantity_derivable_from_text() -> None:
    """Guards against the AI hallucinating a justification for crediting a
    goal that the suggested task has nothing to do with (e.g. a muscle
    relaxation exercise credited as "reading pages")."""
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Tense-and-release scan",
                    "description": "From toes to head, gently tense then release.",
                    "goal_id": "read-goal",
                    "goal_progress_amount": 4,
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="read-goal", title="Read", target=300, unit="pages", progress=0)]

    suggestion = await generator.generate(CravingTrigger.STRESS, goals, 14, None)

    assert suggestion.goal_id is None
    assert suggestion.goal_progress_amount == 0


async def test_generate_clears_goal_when_already_complete() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Read 5 pages",
                    "description": "Just for fun.",
                    "goal_id": "read-goal",
                    "goal_progress_amount": 5,
                }
            )
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="read-goal", title="Read", target=300, unit="pages", progress=300)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    assert suggestion.goal_id is None
    assert suggestion.goal_progress_amount == 0


async def test_generate_ignores_goal_id_not_in_the_given_list() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps({"title": "Run 1 km", "description": "Easy pace.", "goal_id": "made-up-id"})
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="run-goal", title="Run", target=5, unit="km", progress=2)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    assert suggestion.goal_id is None


async def test_generate_includes_local_hour_in_prompt() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json=_responses_payload(json.dumps({"title": "Read a page", "description": "Quietly."})),
        )

    transport = httpx.MockTransport(handler)
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    await generator.generate(CravingTrigger.BOREDOM, [], 4, None)

    user_message = captured["body"]["input"][1]["content"]
    assert "04:00" in user_message


async def test_generate_includes_last_suggestion_for_variety() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json=_responses_payload(json.dumps({"title": "Tidy a drawer", "description": "Quick win."})),
        )

    transport = httpx.MockTransport(handler)
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)

    await generator.generate(CravingTrigger.HABIT, [], 14, "Run 1 km")

    user_message = captured["body"]["input"][1]["content"]
    assert "Run 1 km" in user_message
