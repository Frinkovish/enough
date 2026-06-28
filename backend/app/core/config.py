from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    supabase_url: str
    cors_origins: list[str] = ["*"]
    cors_origin_regex: str | None = None
    azure_openai_endpoint: str | None = None
    azure_openai_api_key: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
