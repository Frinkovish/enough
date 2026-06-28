from app.domain.goal_parser import GoalParser
from app.domain.parsed_goal import ParsedGoal
from app.services.goal_parsing_service import GoalParsingService


class _FakeParser(GoalParser):
    def __init__(self, result: ParsedGoal | None = None, error: Exception | None = None) -> None:
        self._result = result
        self._error = error

    async def parse(self, description: str) -> ParsedGoal:
        if self._error is not None:
            raise self._error
        assert self._result is not None
        return self._result


async def test_no_parser_configured_falls_back_to_generic_goal() -> None:
    service = GoalParsingService(None)

    parsed = await service.parse("Read more")

    assert parsed.title == "Read more"
    assert parsed.target == 1
    assert parsed.unit == "times"


async def test_parser_failure_falls_back_to_generic_goal() -> None:
    parser = _FakeParser(error=RuntimeError("AI is down"))
    service = GoalParsingService(parser)

    parsed = await service.parse("Run 5 km")

    assert parsed.title == "Run 5 km"
    assert parsed.target == 1
    assert parsed.unit == "times"


async def test_parser_success_is_used() -> None:
    parser = _FakeParser(result=ParsedGoal(title="Run", target=5, unit="km"))
    service = GoalParsingService(parser)

    parsed = await service.parse("Run 5 km this month")

    assert parsed.title == "Run"
    assert parsed.target == 5
    assert parsed.unit == "km"
