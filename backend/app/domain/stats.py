from dataclasses import dataclass


@dataclass(frozen=True)
class CravingStats:
    """How many cravings have been delayed, ever, and the current run
    of consecutive delays. Counts up, never frames a relapse as a loss.
    """

    total_delayed: int
    current_streak: int
