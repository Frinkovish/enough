from dataclasses import dataclass


@dataclass(frozen=True)
class ParsedGoal:
    title: str
    target: int
    unit: str
