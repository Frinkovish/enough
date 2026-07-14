from uuid import UUID

from httpx import AsyncClient

from app.api.deps import get_suggestion_service
from app.domain.task_suggestion import TaskCategory, TaskSuggestion
from app.main import app
from tests.conftest import as_user


class _StubSuggestionService:
    async def get_suggestion(
        self, trigger, goals, local_hour, energy, intensity, recent_interventions, location_context=None, addiction_type=None
    ):
        return TaskSuggestion(
            id="ai:stub",
            title="Stretch",
            description="Two minutes.",
            reasoning="Your energy is steady, so something gentle fits.",
            category=TaskCategory.REFLECTION,
            goal_id=goals[0].id if goals else None,
        )


async def test_get_suggestion_requires_auth(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/suggestions",
        json={"trigger": "habit", "local_hour": 14, "energy": "okay", "intensity": "moderate"},
    )

    assert response.status_code == 401


async def test_get_suggestion_returns_a_suggestion(client: AsyncClient, current_user_id: UUID) -> None:
    as_user(current_user_id)
    app.dependency_overrides[get_suggestion_service] = lambda: _StubSuggestionService()

    response = await client.post(
        "/api/v1/suggestions",
        json={"trigger": "boredom", "local_hour": 14, "energy": "okay", "intensity": "moderate"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "Stretch"
    assert body["id"] == "ai:stub"
    assert body["reasoning"] == "Your energy is steady, so something gentle fits."
    assert body["goal_id"] is None


async def test_get_suggestion_includes_goal_id_when_one_is_chosen(
    client: AsyncClient, current_user_id: UUID
) -> None:
    as_user(current_user_id)
    app.dependency_overrides[get_suggestion_service] = lambda: _StubSuggestionService()

    response = await client.post(
        "/api/v1/suggestions",
        json={
            "trigger": "boredom",
            "local_hour": 14,
            "energy": "okay",
            "intensity": "moderate",
            "goals": [{"id": "goal-1", "title": "Run", "target": 5, "unit": "km", "progress": 1}],
        },
    )

    assert response.status_code == 200
    assert response.json()["goal_id"] == "goal-1"
