import json

import httpx
import pytest

from app.domain.goal_parser import GoalParseUnavailableError
from app.integrations.azure_openai_goal_parser import AzureOpenAIGoalParser


def _responses_payload(content: str) -> dict:
    return {"output": [{"type": "message", "content": [{"type": "output_text", "text": content}]}]}


def _transport_returning(payload: dict, status_code: int = 200) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code, json=payload)

    return httpx.MockTransport(handler)


async def test_parse_returns_structured_goal() -> None:
    transport = _transport_returning(
        _responses_payload(json.dumps({"title": "Run", "target": 5, "unit": "km"}))
    )
    parser = AzureOpenAIGoalParser("https://example.test", "key", transport=transport)

    parsed = await parser.parse("Run 5 km this month")

    assert parsed.title == "Run"
    assert parsed.target == 5
    assert parsed.unit == "km"


async def test_parse_raises_on_http_error() -> None:
    transport = _transport_returning({"error": "boom"}, status_code=500)
    parser = AzureOpenAIGoalParser("https://example.test", "key", transport=transport)

    with pytest.raises(GoalParseUnavailableError):
        await parser.parse("Run 5 km this month")


async def test_parse_raises_on_invalid_target() -> None:
    transport = _transport_returning(
        _responses_payload(json.dumps({"title": "Run", "target": 0, "unit": "km"}))
    )
    parser = AzureOpenAIGoalParser("https://example.test", "key", transport=transport)

    with pytest.raises(GoalParseUnavailableError):
        await parser.parse("Run")


async def test_parse_raises_on_malformed_json_content() -> None:
    transport = _transport_returning(_responses_payload("not json"))
    parser = AzureOpenAIGoalParser("https://example.test", "key", transport=transport)

    with pytest.raises(GoalParseUnavailableError):
        await parser.parse("Run")


async def test_parse_raises_when_output_is_empty() -> None:
    transport = _transport_returning({"output": []})
    parser = AzureOpenAIGoalParser("https://example.test", "key", transport=transport)

    with pytest.raises(GoalParseUnavailableError):
        await parser.parse("Run")
