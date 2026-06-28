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


async def test_generate_defaults_goal_progress_amount_to_one_when_missing() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps({"title": "Run a bit", "description": "Easy pace.", "goal_id": "run-goal"})
        )
    )
    generator = AzureOpenAISuggestionGenerator("https://example.test", "key", transport=transport)
    goals = [GoalContext(id="run-goal", title="Run", target=5, unit="km", progress=0)]

    suggestion = await generator.generate(CravingTrigger.BOREDOM, goals, 14, None)

    assert suggestion.goal_id == "run-goal"
    assert suggestion.goal_progress_amount == 1


async def test_generate_clears_goal_when_already_complete() -> None:
    transport = _transport_returning(
        _responses_payload(
            json.dumps(
                {
                    "title": "Read a page",
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
