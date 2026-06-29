import random
from dataclasses import dataclass
from enum import Enum


class TaskCategory(str, Enum):
    READING = "reading"
    PHYSICAL_MOVEMENT = "physical_movement"
    GROUNDING = "grounding"
    REFLECTION = "reflection"
    BREATHING = "breathing"
    LEARNING = "learning"
    ENVIRONMENT_CHANGE = "environment_change"
    SOCIAL_CONNECTION = "social_connection"


@dataclass(frozen=True)
class TaskSuggestion:
    id: str
    title: str
    description: str
    category: TaskCategory

    # Short, user-facing explanation of *why* this specific task fits the
    # person's current psychological state — shown alongside the task
    # itself, not just logged for debugging (unlike goal_reasoning).
    reasoning: str = ""

    goal_id: str | None = None

    # How many units of the chosen goal's own unit this specific task
    # represents (e.g. "Read 5 pages" -> 5 for a goal measured in pages).
    # Fractional when the task's stated quantity converts to a fraction
    # of the goal's unit (e.g. "15 minutes" -> 0.25 for an "hours" goal).
    # Always 0 when goal_id is None.
    goal_progress_amount: float = 0.0


# Static curated suggestions for v1. Swappable later for a remote or
# AI-personalized source (v2) without touching the service or API layers.
# Every TaskCategory has at least one entry so the local fallback pool
# can offer the same variety the AI path is expected to.
TASK_SUGGESTIONS: list[TaskSuggestion] = [
    TaskSuggestion(
        id="reading-1",
        title="Read a few pages",
        description="Pick up whatever book is nearby. Just a few pages.",
        reasoning="A few quiet pages can pull your focus away from the urge.",
        category=TaskCategory.READING,
    ),
    TaskSuggestion(
        id="physical-1",
        title="Take a short walk",
        description="Step outside, even for five minutes.",
        reasoning="Movement burns off restless energy and gives the urge time to pass.",
        category=TaskCategory.PHYSICAL_MOVEMENT,
    ),
    TaskSuggestion(
        id="physical-2",
        title="Stretch it out",
        description="A few minutes of stretching can shift how you feel.",
        reasoning="Shifting your body's state often shifts the urge along with it.",
        category=TaskCategory.PHYSICAL_MOVEMENT,
    ),
    TaskSuggestion(
        id="grounding-1",
        title="Five senses check-in",
        description="Name 5 things you see, 4 you hear, 3 you can touch.",
        reasoning="Naming what's around you anchors your attention in the present.",
        category=TaskCategory.GROUNDING,
    ),
    TaskSuggestion(
        id="reflection-1",
        title="Tidy one small space",
        description="Clear a desk, a drawer, or your bag. Just one.",
        reasoning="A small, finishable task gives you a quick sense of control.",
        category=TaskCategory.REFLECTION,
    ),
    TaskSuggestion(
        id="reflection-2",
        title="Sit in silence",
        description="Two minutes, no phone, just notice what you feel.",
        reasoning="Sitting with the feeling, even briefly, builds tolerance for it.",
        category=TaskCategory.REFLECTION,
    ),
    TaskSuggestion(
        id="breathing-1",
        title="Breathe slowly",
        description="Five slow breaths. In for four, out for six.",
        reasoning="Slow breathing calms the nervous system that's driving the urge.",
        category=TaskCategory.BREATHING,
    ),
    TaskSuggestion(
        id="learning-1",
        title="Plan tomorrow",
        description="Write down your top three things for tomorrow.",
        reasoning="Planning ahead shifts your focus from the urge to what's next.",
        category=TaskCategory.LEARNING,
    ),
    TaskSuggestion(
        id="environment-1",
        title="Change your room",
        description="Open a window, move to another room, or step onto a balcony.",
        reasoning="A change of scenery can interrupt the cue that triggered this.",
        category=TaskCategory.ENVIRONMENT_CHANGE,
    ),
    TaskSuggestion(
        id="social-1",
        title="Send a kind message",
        description="Text someone you care about, just to check in.",
        reasoning="Connecting with someone redirects attention outward, away from the urge.",
        category=TaskCategory.SOCIAL_CONNECTION,
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
        reasoning="Generated specifically for this session.",
        category=TaskCategory.REFLECTION,
    )
