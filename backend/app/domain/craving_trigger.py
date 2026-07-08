from enum import Enum


class CravingTrigger(str, Enum):
    STRESS = "stress"
    BOREDOM = "boredom"
    AFTER_MEALS = "afterMeals"
    COFFEE = "coffee"
    HABIT = "habit"
    SOCIAL = "social"
    MORNING = "morning"
    OTHER = "other"  # fallback for old session rows
