from abc import ABC, abstractmethod

from app.domain.parsed_goal import ParsedGoal


class GoalParseUnavailableError(Exception):
    pass


class GoalParser(ABC):
    @abstractmethod
    async def parse(self, description: str) -> ParsedGoal: ...
