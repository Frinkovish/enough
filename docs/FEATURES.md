Frontend:
- Flutter

Backend:
- FastAPI

Database:
- PostgreSQL

Authentication:
- Supabase

AI:
- GPT API (azure endpoint)

Analytics:
- PostHog

Hosting:
- Railway


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
- Monthly goals
- Full craving questionnaire / AI-personalized suggestions
- Advanced statistics & trends

Rationale: the craving questionnaire and monthly goals add setup friction and UI surface before the app has proven the core hypothesis — that a 20-minute delay with a task suggestion actually redirects a craving. Ship the smallest version of that loop first, then layer on personalization and planning once real usage data justifies it.