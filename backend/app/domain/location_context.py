from enum import Enum


class LocationContext(str, Enum):
    HOME = "home"
    WORK = "work"
    OUTSIDE = "outside"
