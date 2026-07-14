from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    supabase_url: str
    cors_origins: list[str] = ["*"]
    cors_origin_regex: str | None = None
    azure_openai_endpoint: str | None = None
    azure_openai_api_key: str | None = None
    azure_openai_model: str = "gpt-4o-mini"

    # Daily reminder via a Telegram bot — see app/api/v1/reminders.py. This
    # is a single-user personal automation, not a per-account feature, so
    # the recipient and the profile it reads from are both fixed config.
    telegram_bot_token: str | None = None
    telegram_chat_id: str | None = None
    reminder_user_id: str | None = None
    reminder_secret: str | None = None
    supabase_service_role_key: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
