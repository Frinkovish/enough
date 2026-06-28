from datetime import date
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.monthly_goal import MAX_ACTIVE_GOALS
from app.repositories.sqlalchemy_goal_repository import SQLAlchemyGoalRepository
from app.services.goal_service import GoalService, TooManyActiveGoalsError


@pytest.fixture
def service(db_session: AsyncSession) -> GoalService:
    return GoalService(SQLAlchemyGoalRepository(db_session))


async def test_create_goal_and_list_active(service: GoalService) -> None:
    user_id = uuid4()
    today = date.today()

    await service.create_goal(user_id, today, "Run", target=5, unit="km")

    goals = await service.get_active_goals(user_id, today)
    assert len(goals) == 1
    assert goals[0].title == "Run"
    assert goals[0].target == 5
    assert goals[0].unit == "km"
    assert goals[0].progress == 0


async def test_can_have_multiple_active_goals(service: GoalService) -> None:
    user_id = uuid4()
    today = date.today()

    await service.create_goal(user_id, today, "Run", target=5, unit="km")
    await service.create_goal(user_id, today, "Read", target=3, unit="books")

    goals = await service.get_active_goals(user_id, today)
    assert len(goals) == 2


async def test_cannot_exceed_max_active_goals(service: GoalService) -> None:
    user_id = uuid4()
    today = date.today()

    for i in range(MAX_ACTIVE_GOALS):
        await service.create_goal(user_id, today, f"Goal {i}", target=1, unit="times")

    with pytest.raises(TooManyActiveGoalsError):
        await service.create_goal(user_id, today, "One too many", target=1, unit="times")


async def test_increment_progress_caps_at_target(service: GoalService) -> None:
    user_id = uuid4()
    today = date.today()

    goal = await service.create_goal(user_id, today, "Run", target=2, unit="km")

    await service.increment_progress(goal.id)
    updated = await service.increment_progress(goal.id)
    assert updated is not None
    assert updated.progress == 2

    capped = await service.increment_progress(goal.id)
    assert capped is not None
    assert capped.progress == 2


async def test_completed_goal_drops_out_of_active_list(service: GoalService) -> None:
    user_id = uuid4()
    today = date.today()

    goal = await service.create_goal(user_id, today, "Run", target=1, unit="km")
    await service.increment_progress(goal.id)

    goals = await service.get_active_goals(user_id, today)
    assert goals == []
