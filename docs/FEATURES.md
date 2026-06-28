Frontend:
- Flutter

Backend:
- FastAPI (stateless AI gateway only — no database of its own; goal/session
  context is passed in on each request)

Database:
- PostgreSQL (via Supabase; the backend has no direct connection — Flutter
  reads/writes Supabase directly, protected by Row Level Security)

Authentication:
- Supabase

AI:
- GPT API (Azure OpenAI, Responses API)

Analytics:
- PostHog (not yet implemented)

Hosting:
- Render (Blueprint in render.yaml: backend web service + frontend static site)


Features, prioritized by what's required to prove the core loop works:

Core loop (v1 — ship first, nothing else matters until this works):
- Login
- Home screen
- Craving button
- 20-minute timer
- Task suggestions
- Session outcome (smoked / didn't smoke)

v1.1 (fast follow, once the core loop is validated):
- Lightweight craving tag (1 tap: "what triggered this?" — not a full questionnaire)
- Basic stats (cravings delayed, current streak-free count)

v2 (later — adds planning/analysis complexity not needed to prove the hypothesis):
- Monthly goals (done — with edit/delete)
- Full craving questionnaire / AI-personalized suggestions (done — goal-aware,
  considers all active goals, refreshable per session)
- Advanced statistics & trends (done — streaks, weekly trend chart, trigger
  and time-of-day breakdowns, goals completed)

Rationale: the craving questionnaire and monthly goals add setup friction and UI surface before the app has proven the core hypothesis — that a 20-minute delay with a task suggestion actually redirects a craving. Ship the smallest version of that loop first, then layer on personalization and planning once real usage data justifies it.