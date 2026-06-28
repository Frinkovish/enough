from uuid import UUID, uuid4

from httpx import AsyncClient

from tests.conftest import as_user


async def test_start_session_requires_auth(client: AsyncClient) -> None:
    response = await client.post("/api/v1/sessions", json={"trigger": "stress"})

    assert response.status_code == 401


async def test_start_session_returns_a_task_suggestion(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)

    response = await client.post("/api/v1/sessions", json={"trigger": "stress"})

    assert response.status_code == 201
    body = response.json()
    assert body["trigger"] == "stress"
    assert body["outcome"] is None
    assert body["suggested_task"]["title"]


async def test_complete_session_flow(client: AsyncClient, current_user_id: UUID) -> None:
    as_user(current_user_id)

    start_response = await client.post("/api/v1/sessions", json={"trigger": "boredom"})
    session_id = start_response.json()["id"]

    complete_response = await client.post(
        f"/api/v1/sessions/{session_id}/complete",
        json={"outcome": "did_not_smoke"},
    )

    assert complete_response.status_code == 200
    assert complete_response.json()["outcome"] == "did_not_smoke"


async def test_complete_session_already_done_returns_conflict(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)

    start_response = await client.post("/api/v1/sessions", json={"trigger": "habit"})
    session_id = start_response.json()["id"]
    await client.post(f"/api/v1/sessions/{session_id}/complete", json={"outcome": "smoked"})

    response = await client.post(
        f"/api/v1/sessions/{session_id}/complete",
        json={"outcome": "did_not_smoke"},
    )

    assert response.status_code == 409


async def test_complete_session_belonging_to_another_user_returns_not_found(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)
    start_response = await client.post("/api/v1/sessions", json={"trigger": "social"})
    session_id = start_response.json()["id"]

    as_user(uuid4())
    response = await client.post(
        f"/api/v1/sessions/{session_id}/complete",
        json={"outcome": "smoked"},
    )

    assert response.status_code == 404


async def test_get_stats_reflects_completed_sessions(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)

    start_response = await client.post("/api/v1/sessions", json={"trigger": "other"})
    session_id = start_response.json()["id"]
    await client.post(
        f"/api/v1/sessions/{session_id}/complete",
        json={"outcome": "did_not_smoke"},
    )

    response = await client.get("/api/v1/sessions/stats")

    assert response.status_code == 200
    assert response.json() == {"total_delayed": 1, "current_streak": 1}
