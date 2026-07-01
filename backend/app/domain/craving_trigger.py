from enum import Enum


class CravingTrigger(str, Enum):
    HABIT = "habit"
    ANXIETY = "anxiety"
    BOREDOM = "boredom"
    SADNESS = "sadness"
    RESTLESSNESS = "restlessness"
    FATIGUE = "fatigue"
    OTHER = "other"
