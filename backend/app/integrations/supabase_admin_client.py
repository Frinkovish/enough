from dataclasses import dataclass, field
from datetime import date

import httpx


class ProfileFetchError(Exception):
    pass


@dataclass
class GoalProgress:
    title: str
    target: float
    unit: str
    progress: float


@dataclass
class ReminderContext:
    display_name: str | None
    quit_date: str | None
    days_clean_target: int | None
    quit_reasons: list[str] = field(default_factory=list)
    goals: list[GoalProgress] = field(default_factory=list)


async def get_reminder_context(
    *, supabase_url: str, service_role_key: str, user_id: str
) -> ReminderContext:
    """Reads everything the reminder message can personalize with —
    profile fields and this month's goal progress — directly from
    Supabase's PostgREST API using the service role key (bypasses RLS),
    since this runs on a schedule, outside any user's auth session.
    """
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    month_start = date.today().replace(day=1).isoformat()

    base = supabase_url.rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            profile_response = await client.get(
                f"{base}/rest/v1/profiles",
                headers=headers,
                params={
                    "user_id": f"eq.{user_id}",
                    "select": "display_name,quit_date,days_clean_target,quit_reasons",
                },
            )
            profile_response.raise_for_status()
            goals_response = await client.get(
                f"{base}/rest/v1/monthly_goals",
                headers=headers,
                params={
                    "user_id": f"eq.{user_id}",
                    "month": f"eq.{month_start}",
                    "select": "title,target,unit,progress",
                },
            )
            goals_response.raise_for_status()
            profile_rows = profile_response.json()
            goal_rows = goals_response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise ProfileFetchError(str(exc)) from exc

    profile = profile_rows[0] if profile_rows else {}
    goals = [
        GoalProgress(
            title=row["title"],
            target=float(row["target"]),
            unit=row["unit"],
            progress=float(row["progress"]),
        )
        for row in goal_rows
        if float(row["progress"]) < float(row["target"])
    ]

    return ReminderContext(
        display_name=profile.get("display_name"),
        quit_date=profile.get("quit_date"),
        days_clean_target=profile.get("days_clean_target"),
        quit_reasons=list(profile.get("quit_reasons") or []),
        goals=goals,
    )
