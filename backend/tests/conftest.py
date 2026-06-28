import os
from collections.abc import AsyncIterator
from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# Must be set before `app.core.config` is imported anywhere, since
# `get_settings()` is cached on first call.
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("SUPABASE_URL", "https://test-project.supabase.co")

from app.core.security import get_current_user_id  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.db.session import get_db  # noqa: E402
from app.main import app  # noqa: E402

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(TEST_DATABASE_URL, future=True)
TestSessionLocal = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture
async def db_session() -> AsyncIterator[AsyncSession]:
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with TestSessionLocal() as session:
        yield session

    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncIterator[AsyncClient]:
    """An HTTP client with the database swapped for the test session.

    Auth is *not* overridden here: real signature verification (now
    ES256 via Supabase's JWKS, which can't be faked without a private
    key) still runs unless a test explicitly calls `as_user(...)`.
    """

    async def _get_db_override() -> AsyncIterator[AsyncSession]:
        yield db_session

    app.dependency_overrides[get_db] = _get_db_override

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
