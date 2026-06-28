# AI suggestion logic

How `backend/app/integrations/azure_openai_suggestion_generator.py` decides
what to suggest during a craving session, and whether to tie it to a goal.

## 1. Build the prompt

`_build_user_prompt` takes the craving trigger, the user's local hour, their
full list of active goals (id/title/progress/target/unit), and the title of
whatever was suggested last time, and concatenates these into one plain
sentence sent as the "user" message.

## 2. The system prompt's contract

The system prompt asks the AI to:
- Suggest one short, calming, time-of-day-appropriate task.
- Vary it from the last suggestion.
- *Optionally* tie it to one goal — but only if it can state a quantity that
  genuinely matches what the task itself says (e.g. title says "Read 5
  pages" → `goal_progress_amount` must be 5).
- Never claim a whole "hour" or "session" for a few minutes of activity.
- Also return a `goal_reasoning` string — a debug-only explanation of *why*
  it did or didn't pick a goal. This has **zero effect on behavior**; it's
  not read by any of the validation gates below. It exists purely so the
  logs show what the model *thought* it was doing, even when the code
  overrides it.
- Respond as one JSON object: `title`, `description`, `goal_id`,
  `goal_progress_amount`, `goal_reasoning`.

## 3. The API call

Posts to Azure's Responses API. If the configured model is a reasoning
model (`gpt-5`, `o1`, `o3`, etc. — detected by `is_reasoning_model`), the
request adds `reasoning.effort: minimal` and a bumped token budget, since
those models silently spend tokens on hidden reasoning before producing any
visible text. `extract_output_text` then finds the actual message in the
response (reasoning models put a non-text `reasoning` item first, so the
message can't be assumed to be `output[0]`).

Any HTTP error, malformed JSON, or missing field raises
`AISuggestionUnavailableError`, which the caller falls back to the static
task pool for.

## 4. Validating the goal tie — three independent gates, in order

1. **Known goal.** The returned `goal_id` must be one of the goals actually
   sent in the prompt. Anything else becomes `None`.
2. **Uncountable unit.** If that goal's unit is in `_UNCOUNTABLE_UNITS`
   (hours, sessions, classes, workouts, days), the goal is forced to `None`
   regardless of what the AI says — a short task can never honestly equal a
   whole one of these.
3. **Unit not mentioned.** The goal's unit word must literally appear in
   the task's own title/description text. This catches the AI inventing a
   justification for a goal the task has nothing to do with (e.g. a muscle
   relaxation exercise credited as "reading pages").

Only after all three gates pass does the claimed amount get parsed
(defaulting to 1 if missing/invalid), clamped to whatever's left on the
goal (`target - progress`), and dropped entirely if that clamps to 0 (goal
already complete).

## 5. Logging

Every decision — the final `goal_id`/amount, the AI's own stated
`goal_reasoning`, and which of the two backstops fired
(`blocked_uncountable_goal`, `blocked_unit_not_mentioned`) — is logged, so
a suggestion can be audited after the fact instead of guessed at from the
title alone.

## Why the backstops exist (not just the prompt)

The system prompt alone isn't reliable enough: in testing, the AI still
occasionally claimed a goal it had been explicitly told not to (e.g.
crediting a full "hour" toward an hours-based goal for a 2-minute task, or
fabricating a "reading" justification for an unrelated task). The two
backstops in step 4 are deterministic and can't be talked around by the
model, so this class of bug can't silently recur even if the prompt is
later changed or the underlying model is swapped.
