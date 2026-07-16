from dataclasses import dataclass, field
from datetime import date

import httpx


class SupabaseAdminError(Exception):
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
        raise SupabaseAdminError(str(exc)) from exc

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


@dataclass
class ConversationTurn:
    role: str  # "user" or "assistant"
    content: str


@dataclass
class RecentSession:
    trigger: str | None
    outcome: str | None
    addiction_type: str | None
    started_at: str


def _headers(service_role_key: str) -> dict[str, str]:
    return {"apikey": service_role_key, "Authorization": f"Bearer {service_role_key}"}


async def get_conversation_history(
    *, supabase_url: str, service_role_key: str, user_id: str, limit: int = 30
) -> list[ConversationTurn]:
    """The last [limit] turns of the Boo conversation, oldest first, so
    the AI has real continuity across messages instead of starting fresh
    every time."""
    base = supabase_url.rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{base}/rest/v1/boo_conversations",
                headers=_headers(service_role_key),
                params={
                    "user_id": f"eq.{user_id}",
                    "select": "role,content",
                    "order": "created_at.desc",
                    "limit": str(limit),
                },
            )
            response.raise_for_status()
            rows = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise SupabaseAdminError(str(exc)) from exc

    turns = [ConversationTurn(role=row["role"], content=row["content"]) for row in rows]
    turns.reverse()  # was newest-first (for LIMIT to keep the right window); AI wants oldest-first
    return turns


async def save_conversation_turn(
    *, supabase_url: str, service_role_key: str, user_id: str, role: str, content: str
) -> None:
    base = supabase_url.rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{base}/rest/v1/boo_conversations",
                headers={**_headers(service_role_key), "Content-Type": "application/json"},
                json={"user_id": user_id, "role": role, "content": content},
            )
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise SupabaseAdminError(str(exc)) from exc


async def get_recent_sessions(
    *, supabase_url: str, service_role_key: str, user_id: str, limit: int = 5
) -> list[RecentSession]:
    """The most recent completed craving sessions, most recent first —
    gives Boo awareness of recent cravings/relapses without the user
    having to re-explain them."""
    base = supabase_url.rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{base}/rest/v1/craving_sessions",
                headers=_headers(service_role_key),
                params={
                    "user_id": f"eq.{user_id}",
                    "outcome": "not.is.null",
                    "select": "trigger,outcome,addiction_type,started_at",
                    "order": "started_at.desc",
                    "limit": str(limit),
                },
            )
            response.raise_for_status()
            rows = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise SupabaseAdminError(str(exc)) from exc

    return [
        RecentSession(
            trigger=row.get("trigger"),
            outcome=row.get("outcome"),
            addiction_type=row.get("addiction_type"),
            started_at=row["started_at"],
        )
        for row in rows
    ]
