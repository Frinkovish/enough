from dataclasses import dataclass


@dataclass(frozen=True)
class GoalContext:
    """Goal info needed to personalize a suggestion.

    Sent inline by the caller rather than looked up by ID: the goal lives in
    the frontend's own database (Supabase), not this service's database, so
    there is nothing here to look up.
    """

    id: str
    title: str
    target: float
    unit: str
    progress: float
