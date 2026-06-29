import random
from dataclasses import dataclass
from enum import Enum


class TaskCategory(str, Enum):
    SMALL_TASK = "small_task"
    PHYSICAL_ACTIVITY = "physical_activity"
    SPIRITUAL_ACTIVITY = "spiritual_activity"
    PRODUCTIVITY = "productivity"


@dataclass(frozen=True)
class TaskSuggestion:
    id: str
    title: str
    description: str
    category: TaskCategory
    goal_id: str | None = None

    # How many units of the chosen goal's own unit this specific task
    # represents (e.g. "Read 5 pages" -> 5 for a goal measured in pages).
    # Fractional when the task's stated quantity converts to a fraction
    # of the goal's unit (e.g. "15 minutes" -> 0.25 for an "hours" goal).
    # Always 0 when goal_id is None.
    goal_progress_amount: float = 0.0


# Static curated suggestions for v1. Swappable later for a remote or
# AI-personalized source (v2) without touching the service or API layers.
TASK_SUGGESTIONS: list[TaskSuggestion] = [
    TaskSuggestion(
        id="small-task-1",
        title="Tidy one small space",
        description="Clear a desk, a drawer, or your bag. Just one.",
        category=TaskCategory.SMALL_TASK,
    ),
    TaskSuggestion(
        id="small-task-2",
        title="Send a kind message",
        description="Text someone you care about, just to check in.",
        category=TaskCategory.SMALL_TASK,
    ),
    TaskSuggestion(
        id="physical-1",
        title="Take a short walk",
        description="Step outside, even for five minutes.",
        category=TaskCategory.PHYSICAL_ACTIVITY,
    ),
    TaskSuggestion(
        id="physical-2",
        title="Stretch it out",
        description="A few minutes of stretching can shift how you feel.",
        category=TaskCategory.PHYSICAL_ACTIVITY,
    ),
    TaskSuggestion(
        id="spiritual-1",
        title="Breathe slowly",
        description="Five slow breaths. In for four, out for six.",
        category=TaskCategory.SPIRITUAL_ACTIVITY,
    ),
    TaskSuggestion(
        id="spiritual-2",
        title="Sit in silence",
        description="Two minutes, no phone, just notice what you feel.",
        category=TaskCategory.SPIRITUAL_ACTIVITY,
    ),
    TaskSuggestion(
        id="productivity-1",
        title="Clear one small task",
        description="Pick one thing from your list and just finish it.",
        category=TaskCategory.PRODUCTIVITY,
    ),
    TaskSuggestion(
        id="productivity-2",
        title="Plan tomorrow",
        description="Write down your top three things for tomorrow.",
        category=TaskCategory.PRODUCTIVITY,
    ),
]

_SUGGESTIONS_BY_ID = {suggestion.id: suggestion for suggestion in TASK_SUGGESTIONS}


def pick_random_suggestion() -> TaskSuggestion:
    return random.choice(TASK_SUGGESTIONS)


def get_suggestion_by_id(suggestion_id: str) -> TaskSuggestion:
    """Looks up a static suggestion, or returns a generic placeholder
    for synthetic ids (`goal:...`, `ai:...`) whose actual generated
    title/description aren't persisted — only the id is stored on the
    session row, so that text can't be recovered after the fact.
    """
    suggestion = _SUGGESTIONS_BY_ID.get(suggestion_id)
    if suggestion is not None:
        return suggestion
    return TaskSuggestion(
        id=suggestion_id,
        title="Personalized suggestion",
        description="A suggestion generated specifically for this session.",
        category=TaskCategory.PRODUCTIVITY,
    )
