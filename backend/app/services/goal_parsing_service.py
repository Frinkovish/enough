from app.domain.goal_parser import GoalParser
from app.domain.parsed_goal import ParsedGoal


class GoalParsingService:
    """Turns a free-text goal description into a structured target/unit.

    Falls back to a generic 1/"times" goal if AI parsing isn't configured
    or fails — creating a goal should never be blocked by the AI being down.
    """

    def __init__(self, parser: GoalParser | None) -> None:
        self._parser = parser

    async def parse(self, description: str) -> ParsedGoal:
        if self._parser is not None:
            try:
                return await self._parser.parse(description)
            except Exception:  # noqa: BLE001 — any AI failure must fall back
                pass

        return ParsedGoal(title=description.strip(), target=1, unit="times")
