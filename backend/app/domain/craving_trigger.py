from enum import Enum


class CravingTrigger(str, Enum):
    STRESS = "stress"
    ANXIETY = "anxiety"
    BOREDOM = "boredom"
    SADNESS = "sadness"
    LONELINESS = "loneliness"
    FATIGUE = "fatigue"
    OTHER = "other"
