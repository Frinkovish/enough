from enum import Enum


class CravingTrigger(str, Enum):
    STRESS = "stress"
    ANXIETY = "anxiety"
    BOREDOM = "boredom"
    SADNESS = "sadness"
    RESTLESSNESS = "restlessness"
    FATIGUE = "fatigue"
    OTHER = "other"
