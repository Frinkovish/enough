from uuid import UUID

from httpx import AsyncClient

from app.api.deps import get_goal_parser
from app.main import app
from tests.conftest import as_user


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
