from enum import Enum


class AddictionType(str, Enum):
    CIGARETTES = "cigarettes"
    WEED = "weed"
    MASTURBATION = "masturbation"
    OTHER = "other"
