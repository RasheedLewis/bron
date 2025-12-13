"""
Claude AI integration service.
Placeholder for PR-02 implementation.
"""

from anthropic import AsyncAnthropic
from app.core.config import settings


class ClaudeService:
    """Service for interacting with Claude API."""

    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.model = settings.claude_model
        self.max_tokens = settings.claude_max_tokens

    async def generate_response(
        self,
        messages: list[dict],
        system_prompt: str | None = None,
    ) -> str:
        """
        Generate a response from Claude.
        
        To be fully implemented in PR-02.
        """
        # Placeholder implementation
        raise NotImplementedError("Claude integration will be implemented in PR-02")

    async def generate_ui_recipe(
        self,
        task_context: dict,
        missing_info: list[str],
    ) -> dict:
        """
        Generate a UI Recipe for collecting missing information.
        
        To be fully implemented in PR-02.
        """
        # Placeholder implementation
        raise NotImplementedError("UI Recipe generation will be implemented in PR-02")


# Singleton instance
claude_service = ClaudeService()

