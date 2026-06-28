from pydantic import BaseModel, Field

from app.domain.parsed_goal import ParsedGoal


class ParseGoalRequest(BaseModel):
    description: str = Field(min_length=1, max_length=200)


class ParsedGoalRead(BaseModel):
    title: str
    target: int
    unit: str

    @classmethod
    def from_domain(cls, parsed: ParsedGoal) -> "ParsedGoalRead":
        return cls(title=parsed.title, target=parsed.target, unit=parsed.unit)
