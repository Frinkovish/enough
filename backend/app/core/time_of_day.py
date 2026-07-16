import logging
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

logger = logging.getLogger("app.reminders")


def day_part(timezone_name: str) -> str:
    """A coarse "morning"/"afternoon"/"evening"/"night" label for the
    given IANA timezone — used wherever a background job needs to
    reference the recipient's local time with no client to report it."""
    try:
        hour = datetime.now(ZoneInfo(timezone_name)).hour
    except ZoneInfoNotFoundError:
        logger.warning("Unknown timezone %r, defaulting to UTC", timezone_name)
        hour = datetime.now(ZoneInfo("UTC")).hour
    if 5 <= hour < 12:
        return "morning"
    if 12 <= hour < 17:
        return "afternoon"
    if 17 <= hour < 22:
        return "evening"
    return "night"
