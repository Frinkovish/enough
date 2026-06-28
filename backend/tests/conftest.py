import os
from collections.abc import AsyncIterator
from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

# Must be set before `app.core.config` is imported anywhere, since
# `get_settings()` is cached on first call.
os.environ.setdefault("SUPABASE_URL", "https://test-project.supabase.co")

from app.core.security import get_current_user_id  # noqa: E402
from app.main import app  # noqa: E402


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    """An HTTP client against the real app.

    Auth is *not* overridden here: real signature verification (ES256
    via Supabase's JWKS, which can't be faked without a private key)
    still runs unless a test explicitly calls `as_user(...)`.
    """
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


def as_user(user_id: UUID) -> None:
    """Bypasses real JWT verification for the current test, asserting
    the request is authenticated as `user_id`. Cleared automatically
    by the `client` fixture's teardown.
    """
    app.dependency_overrides[get_current_user_id] = lambda: user_id


@pytest.fixture
def current_user_id() -> UUID:
    return uuid4()
