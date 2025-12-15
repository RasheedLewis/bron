"""
Application configuration using Pydantic settings.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # API Keys
    anthropic_api_key: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False

    # Database
    database_url: str = "sqlite+aiosqlite:///./bron.db"

    # Claude Configuration
    claude_model: str = "claude-sonnet-4-20250514"
    claude_max_tokens: int = 1024  # Keep responses concise
    claude_timeout: int = 60  # API timeout in seconds
    
    # OAuth - Google
    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = "bron://oauth/callback/google"
    
    # OAuth - Apple
    apple_client_id: str = ""
    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_private_key_path: str = ""
    
    # OAuth Base URL
    oauth_base_url: str = "http://localhost:8000"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()

