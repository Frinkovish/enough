import json

import httpx

from app.domain.goal_parser import GoalParseUnavailableError, GoalParser
from app.domain.parsed_goal import ParsedGoal

_SYSTEM_PROMPT = (
    "You turn a short free-text monthly goal description into a structured goal. Pick a "
    "short title (<=6 words), an integer target (>=1), and a short unit (e.g. km, books, "
    "times, minutes, days). If the description has no clear number, choose a sensible "
    'default for one month. Respond ONLY with compact JSON: {"title": "...", "target": '
    '<integer>, "unit": "..."}.'
)


class AzureOpenAIGoalParser(GoalParser):
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

    async def parse(self, description: str) -> ParsedGoal:
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
                            {"role": "user", "content": description},
                        ],
                        "max_output_tokens": 100,
                        "temperature": 0.3,
                        "text": {"format": {"type": "json_object"}},
                    },
                )
                response.raise_for_status()
                content = response.json()["output"][0]["content"][0]["text"]
                parsed = json.loads(content)
                title = str(parsed["title"]).strip()
                unit = str(parsed["unit"]).strip()
                target = int(parsed["target"])
        except (
            httpx.HTTPError,
            KeyError,
            IndexError,
            ValueError,
            TypeError,
            json.JSONDecodeError,
        ) as exc:
            raise GoalParseUnavailableError(str(exc)) from exc

        if not title or not unit or target < 1:
            raise GoalParseUnavailableError("Invalid title/target/unit from AI response")

        return ParsedGoal(title=title, target=target, unit=unit)
