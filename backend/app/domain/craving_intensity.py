from enum import Enum


class CravingIntensity(str, Enum):
    """How strong the urge is right now — determines whether the
    suggestion should focus on stabilization or growth."""

    MILD = "mild"
    MODERATE = "moderate"
    STRONG = "strong"
