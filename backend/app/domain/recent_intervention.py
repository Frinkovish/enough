from dataclasses import dataclass

from app.domain.task_suggestion import TaskCategory


@dataclass(frozen=True)
class RecentIntervention:
    """A previously suggested task, sent inline by the caller so the AI
    can vary its category choice across the last several interventions,
    not just the single most recent one."""

    title: str
    category: TaskCategory
