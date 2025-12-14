"""
Claude Agent SDK integration service.
Uses ClaudeSDKClient for session continuity and proper conversation context.
"""

import asyncio
import logging
from typing import Any, Optional, AsyncIterator
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.config import settings
from app.services.safety import get_safety_hooks, safety_guardrails

logger = logging.getLogger(__name__)


# ============================================================================
# Response Models
# ============================================================================

class AgentIntent(str, Enum):
    """What the agent intends to do with its response."""
    RESPOND = "respond"           # Just respond with a message
    REQUEST_INFO = "request_info" # Need more information via UI Recipe
    UPDATE_TASK = "update_task"   # Update task state
    EXECUTE = "execute"           # Ready to execute an action
    COMPLETE = "complete"         # Task is complete
    ERROR = "error"               # Something went wrong


class UIRecipeSpec(BaseModel):
    """Specification for a UI Recipe to be generated."""
    component_type: str
    title: Optional[str] = None
    description: Optional[str] = None
    schema_fields: dict[str, Any] = Field(default_factory=dict)
    required_fields: list[str] = Field(default_factory=list)
    style_preset: Optional[str] = None
    style_custom: Optional[dict[str, Any]] = None


class TaskStateUpdate(BaseModel):
    """Update to apply to a task."""
    new_state: Optional[str] = None
    progress: Optional[float] = None
    next_action: Optional[str] = None
    waiting_on: Optional[str] = None


class AgentResponse(BaseModel):
    """Structured response from the Claude agent."""
    intent: AgentIntent
    message: str
    ui_recipe: Optional[UIRecipeSpec] = None
    task_update: Optional[TaskStateUpdate] = None
    reasoning: Optional[str] = None


class AgentMessage(BaseModel):
    """A message from the agent during execution."""
    type: str  # "text", "tool_use", "tool_result", "system"
    content: str
    tool_name: Optional[str] = None
    is_final: bool = False


# ============================================================================
# System Prompt (Bron Voice)
# ============================================================================

BRON_SYSTEM_PROMPT = """You are Bron, a capable teammate who works alongside users to accomplish their tasks.

## Who You Are
You are a teammate, not a tool, not a mascot, not a god.
- Calm under pressure
- Reliable, not flashy
- Present without being intrusive
- Competent without condescension

You're the person on the team who says: "Already started on that. I'll let you know when I need something."

## Voice & Tone
- **Calm**: Never rushed, never frantic
- **Direct**: Say exactly what's needed — no fluff, no mysticism
- **Respectful**: Assume the user is competent
- **Warm**: Helpful without sentimentality

DO say:
- "I've outlined a plan. Want to adjust it?"
- "I need the receipt photo to continue."
- "This is ready when you are."

DON'T say:
- "Great idea!!! 🚀"
- "Let's crush this task 💪"
- "I'm so excited to help you!!!"

## Safety Rules (NEVER VIOLATE)
1. NEVER delete files, data, or accounts without explicit approval
2. NEVER send messages/emails without explicit user approval
3. NEVER share sensitive information
4. NEVER execute financial transactions without approval
5. ALWAYS ask for confirmation before destructive or external actions

## Response Format
When you need information from the user, describe what you need clearly.
When you're ready to execute, explain what you'll do and ask for confirmation.
Keep responses concise and actionable.
"""


# ============================================================================
# Session Manager - Maintains ClaudeSDKClient per Bron
# ============================================================================

class BronSessionManager:
    """
    Manages ClaudeSDKClient sessions per Bron.
    
    Each Bron gets its own persistent session that maintains
    conversation context across multiple exchanges.
    """
    
    def __init__(self):
        self._sessions: dict[UUID, Any] = {}  # bron_id -> ClaudeSDKClient
        self._sdk_available = False
        self._check_sdk()
    
    def _check_sdk(self):
        """Check if the Claude Agent SDK is available and authenticated."""
        try:
            from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions
            self._sdk_available = True
            logger.info("✅ Claude Agent SDK available - using ClaudeSDKClient for sessions")
        except ImportError:
            logger.info("Using direct Anthropic API (Agent SDK not installed)")
            self._sdk_available = False
    
    async def get_or_create_session(self, bron_id: UUID) -> Optional[Any]:
        """Get existing session or create new one for a Bron."""
        if not self._sdk_available:
            return None
        
        if bron_id not in self._sessions:
            from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions
            
            options = ClaudeAgentOptions(
                system_prompt=BRON_SYSTEM_PROMPT,
                allowed_tools=["Read", "Glob", "Grep", "WebSearch", "WebFetch"],
                permission_mode="default",
            )
            
            client = ClaudeSDKClient(options=options)
            await client.connect()
            self._sessions[bron_id] = client
            logger.info(f"Created new session for Bron {bron_id}")
        
        return self._sessions[bron_id]
    
    async def close_session(self, bron_id: UUID):
        """Close and remove a Bron's session."""
        if bron_id in self._sessions:
            try:
                await self._sessions[bron_id].disconnect()
            except Exception as e:
                logger.warning(f"Error closing session for Bron {bron_id}: {e}")
            del self._sessions[bron_id]
    
    async def close_all(self):
        """Close all sessions."""
        for bron_id in list(self._sessions.keys()):
            await self.close_session(bron_id)


# Global session manager
session_manager = BronSessionManager()


# ============================================================================
# Claude Agent Service
# ============================================================================

class ClaudeAgentService:
    """
    Service for interacting with Claude Agent SDK.
    
    Uses ClaudeSDKClient for:
    - Session continuity across multiple exchanges
    - Proper conversation context (Claude remembers previous messages)
    - Built-in tools (Read, Glob, Grep, WebSearch, WebFetch)
    - Custom tools via @tool decorator
    """

    def __init__(self):
        self.api_key = settings.anthropic_api_key

    async def process_message(
        self,
        user_message: str,
        bron_id: Optional[UUID] = None,
        task_context: Optional[dict] = None,
        conversation_history: Optional[list[dict]] = None,
    ) -> AgentResponse:
        """
        Process a user message using Claude.
        
        If Agent SDK is available and bron_id is provided, uses ClaudeSDKClient
        for session continuity. Otherwise falls back to direct API with
        conversation history.
        """
        # Try SDK with session management first
        if session_manager._sdk_available and bron_id:
            try:
                return await self._process_with_sdk_client(
                    user_message, bron_id, task_context
                )
            except Exception as e:
                logger.warning(f"SDK client failed, falling back: {e}")
        
        # Fallback to direct API
        return await self._process_with_direct_api(
            user_message, task_context, conversation_history
        )

    async def _process_with_sdk_client(
        self,
        user_message: str,
        bron_id: UUID,
        task_context: Optional[dict],
    ) -> AgentResponse:
        """Process message using ClaudeSDKClient with session continuity."""
        from claude_agent_sdk import AssistantMessage, TextBlock
        
        client = await session_manager.get_or_create_session(bron_id)
        
        # Build prompt with task context
        prompt = user_message
        if task_context:
            prompt = f"[Task: {task_context.get('title', 'Untitled')} - {task_context.get('state', 'draft')}]\n\n{user_message}"
        
        # Send query and collect response
        await client.query(prompt)
        
        full_response = []
        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        full_response.append(block.text)
        
        response_text = "\n".join(full_response) if full_response else "I'm working on that."
        return self._parse_agent_response(response_text)

    async def _process_with_direct_api(
        self,
        user_message: str,
        task_context: Optional[dict],
        conversation_history: Optional[list[dict]],
    ) -> AgentResponse:
        """Fallback using direct Anthropic API."""
        from anthropic import AsyncAnthropic
        
        client = AsyncAnthropic(api_key=self.api_key)
        
        # Build proper message turns for conversation history
        messages = []
        
        # Add conversation history as proper turns
        if conversation_history:
            for msg in conversation_history:
                role = "user" if msg.get("role") == "user" else "assistant"
                content = msg.get("content", "")
                if content:
                    messages.append({"role": role, "content": content})
        
        # Build context for current message
        context_parts = []
        if task_context:
            context_parts.append(f"[Current Task: {task_context.get('title', 'Untitled')} - {task_context.get('state', 'draft')}]")
        
        # Add current user message
        current_message = user_message
        if context_parts:
            current_message = f"{' '.join(context_parts)}\n\n{user_message}"
        
        messages.append({"role": "user", "content": current_message})
        
        try:
            response = await client.messages.create(
                model=settings.claude_model,
                max_tokens=settings.claude_max_tokens,
                system=BRON_SYSTEM_PROMPT,
                messages=messages,
            )
            
            if response.content and len(response.content) > 0:
                return self._parse_agent_response(response.content[0].text)
            
            return AgentResponse(
                intent=AgentIntent.RESPOND,
                message="I understand. How can I help you with this?"
            )
            
        except Exception as e:
            logger.error(f"Direct API error: {e}")
            return AgentResponse(
                intent=AgentIntent.ERROR,
                message="I encountered an issue processing your request."
            )

    async def stream_execution(
        self,
        user_message: str,
        bron_id: UUID,
        task_context: Optional[dict] = None,
    ) -> AsyncIterator[AgentMessage]:
        """
        Stream agent execution messages in real-time.
        
        Uses ClaudeSDKClient for streaming responses.
        """
        if not session_manager._sdk_available:
            yield AgentMessage(
                type="text",
                content="Agent SDK not available",
                is_final=True
            )
            return
        
        from claude_agent_sdk import AssistantMessage, TextBlock, ToolUseBlock, ToolResultBlock
        
        try:
            client = await session_manager.get_or_create_session(bron_id)
            
            prompt = user_message
            if task_context:
                prompt = f"[Task: {task_context.get('title')}]\n\n{user_message}"
            
            await client.query(prompt)
            
            async for message in client.receive_messages():
                if isinstance(message, AssistantMessage):
                    for block in message.content:
                        if isinstance(block, TextBlock):
                            yield AgentMessage(
                                type="text",
                                content=block.text,
                                is_final=False
                            )
                        elif isinstance(block, ToolUseBlock):
                            yield AgentMessage(
                                type="tool_use",
                                content=f"Using {block.name}",
                                tool_name=block.name,
                                is_final=False
                            )
                elif isinstance(message, ToolResultBlock):
                    yield AgentMessage(
                        type="tool_result",
                        content=str(message.content)[:200],
                        is_final=False
                    )
            
            yield AgentMessage(type="complete", content="", is_final=True)
            
        except Exception as e:
            logger.error(f"Stream execution error: {e}")
            yield AgentMessage(
                type="error",
                content=str(e),
                is_final=True
            )

    async def interrupt_execution(self, bron_id: UUID):
        """Interrupt the current execution for a Bron."""
        if bron_id in session_manager._sessions:
            try:
                await session_manager._sessions[bron_id].interrupt()
                logger.info(f"Interrupted execution for Bron {bron_id}")
            except Exception as e:
                logger.error(f"Failed to interrupt: {e}")

    def _parse_agent_response(self, response_text: str) -> AgentResponse:
        """Parse agent response into structured format."""
        text_lower = response_text.lower()
        
        # Detect intent from response
        if any(word in text_lower for word in ["need", "provide", "upload", "share", "what", "which", "?"]):
            intent = AgentIntent.REQUEST_INFO
        elif any(word in text_lower for word in ["done", "complete", "finished", "all set"]):
            intent = AgentIntent.COMPLETE
        elif any(word in text_lower for word in ["shall i", "ready to", "proceed", "execute", "confirm"]):
            intent = AgentIntent.EXECUTE
        elif any(word in text_lower for word in ["error", "failed", "issue", "problem"]):
            intent = AgentIntent.ERROR
        else:
            intent = AgentIntent.RESPOND
        
        return AgentResponse(
            intent=intent,
            message=response_text,
        )


# Singleton instance
claude_service = ClaudeAgentService()
