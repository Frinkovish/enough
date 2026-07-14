import httpx


class ProfileFetchError(Exception):
    pass


async def get_days_clean_info(
    *, supabase_url: str, service_role_key: str, user_id: str
) -> tuple[str | None, int | None]:
    """Returns (quit_date, days_clean_target) for the given user.

    Reads directly from Supabase's PostgREST API using the service role
    key, bypassing RLS — needed because this runs on a schedule, outside
    any user's auth session.
    """
    url = f"{supabase_url.rstrip('/')}/rest/v1/profiles"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    params = {"user_id": f"eq.{user_id}", "select": "quit_date,days_clean_target"}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers=headers, params=params)
            response.raise_for_status()
            rows = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise ProfileFetchError(str(exc)) from exc

    if not rows:
        return None, None
    row = rows[0]
    return row.get("quit_date"), row.get("days_clean_target")
