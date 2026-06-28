from enum import Enum


class CravingTrigger(str, Enum):
    STRESS = "stress"
    BOREDOM = "boredom"
    SOCIAL = "social"
    HABIT = "habit"
    OTHER = "other"
