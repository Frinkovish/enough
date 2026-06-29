from enum import Enum


class EnergyLevel(str, Enum):
    """Self-reported executive capacity right now — a task that exceeds
    this is likely to be rejected, so it calibrates task difficulty."""

    EMPTY = "empty"
    LOW = "low"
    OKAY = "okay"
    HIGH = "high"
