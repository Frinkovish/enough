import re

# Minutes-equivalent for each recognized time unit, so any pair of time
# units can be converted through this common base (e.g. "15 minutes"
# satisfies an "hours" goal: 15 * 1.0 / 60.0 = 0.25).
_TIME_UNITS_TO_MINUTES = {
    "second": 1 / 60,
    "seconds": 1 / 60,
    "sec": 1 / 60,
    "secs": 1 / 60,
    "minute": 1.0,
    "minutes": 1.0,
    "min": 1.0,
    "mins": 1.0,
    "hour": 60.0,
    "hours": 60.0,
    "hr": 60.0,
    "hrs": 60.0,
    "day": 1440.0,
    "days": 1440.0,
}

_WORD_NUMBERS = {
    "half": 0.5,
    "one": 1.0,
    "two": 2.0,
    "three": 3.0,
    "four": 4.0,
    "five": 5.0,
    "six": 6.0,
    "seven": 7.0,
    "eight": 8.0,
    "nine": 9.0,
    "ten": 10.0,
    "fifteen": 15.0,
    "twenty": 20.0,
    "thirty": 30.0,
    "forty": 40.0,
    "fifty": 50.0,
    "sixty": 60.0,
}

_TOKEN_PATTERN = re.compile(r"[a-zA-Z]+|\d+(?:\.\d+)?")


def extract_amount_in_unit(text: str, goal_unit: str) -> float | None:
    """Looks for an explicit "<quantity> <unit>" phrase in `text` that
    corresponds to `goal_unit` — either the literal same word (plural/
    singular-insensitive), or, for time units, a convertible one (e.g.
    "15 minutes" satisfies an "hours" goal). Returns None if no such
    phrase exists, so a goal can never be credited with an amount that
    isn't actually stated in the task's own wording.

    Any unit is eligible this way — there's no hardcoded list of
    forbidden units, just a requirement that the text actually states a
    matching quantity.
    """
    goal_unit_norm = goal_unit.strip().lower()
    if not goal_unit_norm:
        return None
    goal_unit_singular = goal_unit_norm.rstrip("s")
    goal_is_time_unit = goal_unit_norm in _TIME_UNITS_TO_MINUTES

    tokens = _TOKEN_PATTERN.findall(text.lower())
    for index, token in enumerate(tokens[:-1]):
        number = _as_number(token)
        if number is None:
            continue
        word = tokens[index + 1]
        if word == goal_unit_norm or word.rstrip("s") == goal_unit_singular:
            return number
        if goal_is_time_unit and word in _TIME_UNITS_TO_MINUTES:
            return number * _TIME_UNITS_TO_MINUTES[word] / _TIME_UNITS_TO_MINUTES[goal_unit_norm]
    return None


def _as_number(token: str) -> float | None:
    if re.fullmatch(r"\d+(?:\.\d+)?", token):
        return float(token)
    return _WORD_NUMBERS.get(token)


def format_number(value: float) -> str:
    """Formats a whole number without a trailing ".0" (e.g. 5.0 -> "5"),
    while still showing fractional amounts plainly (e.g. 1.25 -> "1.25")."""
    if value == int(value):
        return str(int(value))
    return f"{value:.2f}".rstrip("0").rstrip(".")
