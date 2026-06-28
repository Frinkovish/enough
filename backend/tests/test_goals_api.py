from uuid import UUID

from httpx import AsyncClient

from app.api.deps import get_goal_parser
from app.domain.monthly_goal import MAX_ACTIVE_GOALS
from app.main import app
from tests.conftest import as_user


async def test_list_active_goals_empty_by_default(client: AsyncClient, current_user_id: UUID) -> None:
    as_user(current_user_id)

    response = await client.get("/api/v1/goals")

    assert response.status_code == 200
    assert response.json() == []


async def test_parse_goal_requires_auth(client: AsyncClient) -> None:
    response = await client.post("/api/v1/goals/parse", json={"description": "Run 5 km"})

    assert response.status_code == 401


async def test_parse_goal_without_ai_configured_falls_back(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)
    app.dependency_overrides[get_goal_parser] = lambda: None

    response = await client.post("/api/v1/goals/parse", json={"description": "Run 5 km"})

    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "Run 5 km"
    assert body["target"] == 1
    assert body["unit"] == "times"


async def test_create_and_list_goal(client: AsyncClient, current_user_id: UUID) -> None:
    as_user(current_user_id)

    create_response = await client.post(
        "/api/v1/goals", json={"title": "Run", "target": 5, "unit": "km"}
    )

    assert create_response.status_code == 201
    body = create_response.json()
    assert body["title"] == "Run"
    assert body["progress"] == 0

    list_response = await client.get("/api/v1/goals")
    assert len(list_response.json()) == 1


async def test_creating_a_sixth_goal_returns_conflict(client: AsyncClient, current_user_id: UUID) -> None:
    as_user(current_user_id)

    for i in range(MAX_ACTIVE_GOALS):
        response = await client.post(
            "/api/v1/goals", json={"title": f"Goal {i}", "target": 1, "unit": "times"}
        )
        assert response.status_code == 201

    response = await client.post(
        "/api/v1/goals", json={"title": "One too many", "target": 1, "unit": "times"}
    )

    assert response.status_code == 409


async def test_completing_a_session_linked_to_a_goal_increments_it(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)

    goal_response = await client.post(
        "/api/v1/goals", json={"title": "Run", "target": 5, "unit": "km"}
    )
    goal_id = goal_response.json()["id"]

    start_response = await client.post(
        "/api/v1/sessions", json={"trigger": "stress", "goal_id": goal_id}
    )
    session_id = start_response.json()["id"]

    await client.post(
        f"/api/v1/sessions/{session_id}/complete",
        json={"outcome": "did_not_smoke"},
    )

    goals = (await client.get("/api/v1/goals")).json()
    assert goals[0]["progress"] == 1


async def test_completing_a_session_linked_to_a_goal_with_smoked_outcome_does_not_increment(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)

    goal_response = await client.post(
        "/api/v1/goals", json={"title": "Run", "target": 5, "unit": "km"}
    )
    goal_id = goal_response.json()["id"]

    start_response = await client.post(
        "/api/v1/sessions", json={"trigger": "stress", "goal_id": goal_id}
    )
    session_id = start_response.json()["id"]

    await client.post(
        f"/api/v1/sessions/{session_id}/complete",
        json={"outcome": "smoked"},
    )

    goals = (await client.get("/api/v1/goals")).json()
    assert goals[0]["progress"] == 0
