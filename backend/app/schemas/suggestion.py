from pydantic import BaseModel, Field

from app.domain.craving_intensity import CravingIntensity
from app.domain.craving_trigger import CravingTrigger
from app.domain.energy_level import EnergyLevel
from app.domain.goal_context import GoalContext
from app.domain.recent_intervention import RecentIntervention
from app.domain.task_suggestion import TaskCategory, TaskSuggestion


class GoalContextIn(BaseModel):
    id: str
    title: str
    target: float
    unit: str
    progress: float

    def to_domain(self) -> GoalContext:
        return GoalContext(
            id=self.id, title=self.title, target=self.target, unit=self.unit, progress=self.progress
        )


class RecentInterventionIn(BaseModel):
    title: str
    category: TaskCategory

    def to_domain(self) -> RecentIntervention:
        return RecentIntervention(title=self.title, category=self.category)


class SuggestionRequest(BaseModel):
    trigger: CravingTrigger
    goals: list[GoalContextIn] = []
    local_hour: int = Field(ge=0, le=23)
    energy: EnergyLevel
    intensity: CravingIntensity
    recent_interventions: list[RecentInterventionIn] = []


class SuggestionRead(BaseModel):
    id: str
    title: str
    description: str
    reasoning: str = ""
    category: TaskCategory
    goal_id: str | None = None
    goal_progress_amount: float = 0.0

    @classmethod
    def from_domain(cls, suggestion: TaskSuggestion) -> "SuggestionRead":
        return cls(
            id=suggestion.id,
            title=suggestion.title,
            description=suggestion.description,
            reasoning=suggestion.reasoning,
            category=suggestion.category,
            goal_id=suggestion.goal_id,
            goal_progress_amount=suggestion.goal_progress_amount,
        )
