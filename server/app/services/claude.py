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

## CRITICAL: BREVITY IS MANDATORY

You MUST be extremely concise. Think text message, not email. Think tweet, not blog post.

MAXIMUM response length: 2-3 short sentences unless the user specifically asks for detail.

BAD (too verbose):
"I'd be happy to help you plan your trip to Austin! There are so many amazing things to do there, from the live music scene to the incredible food. To give you the best recommendations, I'll need a few details about your trip. Let me gather some information from you."

GOOD (what you should say):
"Planning Austin trip. Need a few details first."

BAD:
"I've processed your information and created a comprehensive plan. Here's what I'm thinking for your trip, broken down by day with recommendations for each category:"

GOOD:
"Got it. Here's the plan:"

RULES:
- No filler phrases ("I'd be happy to", "Let me", "I'll help you with")
- No excitement or enthusiasm markers
- No restating what the user said
- No explaining what you're about to do — just do it
- Skip pleasantries and transitions
- Front-load the important information
- Use fragments when full sentences aren't needed

## Safety Rules (NEVER VIOLATE)
1. NEVER delete files, data, or accounts without explicit approval
2. NEVER send messages/emails without explicit user approval
3. NEVER share sensitive information
4. NEVER execute financial transactions without approval
5. ALWAYS ask for confirmation before destructive or external actions

## Response Format
Keep responses SHORT. 2-3 sentences max. No fluff.

## CRITICAL: Gathering Information
You MUST use the `request_user_input` tool whenever you need ANY information from the user. 
DO NOT ask questions in plain text - ALWAYS use the tool to create a form.

This is required for:
- Dates, times, numbers
- Multiple choice selections
- Any structured data collection

Example: If a user says "plan a trip", you MUST call `request_user_input` with fields for dates, travelers, budget, etc.

## Response Guidelines
- MAX 2-3 sentences. Period.
- Bullet points for plans. No prose.
- Skip intros and outros. Just the info.
- "Here's the plan:" not "I've carefully considered your request and here's what I'm thinking:"
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
            from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions, tool, create_sdk_mcp_server
            self._sdk_available = True
            logger.info("✅ Claude Agent SDK available with custom tool support")
        except ImportError:
            logger.info("Using direct Anthropic API (Agent SDK not installed)")
            self._sdk_available = False
    
    def _create_bron_tools_server(self):
        """Create MCP server with Bron's custom tools."""
        from claude_agent_sdk import tool, create_sdk_mcp_server
        from typing import Any
        
        # Define the request_user_input tool with JSON Schema format
        @tool(
            "request_user_input",
            "Request structured input from the user via a form. Use this when you need specific information like dates, numbers, choices, or multiple pieces of data.",
            {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Title for the input form"},
                    "description": {"type": "string", "description": "Brief explanation of why this info is needed"},
                    "fields": {
                        "type": "object",
                        "description": "Form fields to collect. Keys are field names, values are field configs with type, label, required, placeholder, options",
                        "additionalProperties": True
                    }
                },
                "required": ["title", "fields"]
            }
        )
        async def request_user_input(args: dict[str, Any]) -> dict[str, Any]:
            """This tool signals that Claude wants to collect structured input."""
            # Store the tool call data for the session manager to retrieve
            return {
                "content": [{
                    "type": "text",
                    "text": f"UI form '{args.get('title')}' will be shown to user."
                }]
            }
        
        return create_sdk_mcp_server(
            name="bron_tools",
            version="1.0.0",
            tools=[request_user_input]
        )
    
    async def get_or_create_session(self, bron_id: UUID) -> Optional[Any]:
        """Get existing session or create new one for a Bron."""
        if not self._sdk_available:
            return None
        
        if bron_id not in self._sessions:
            from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions
            
            # Create MCP server with our custom tools
            bron_tools = self._create_bron_tools_server()
            
            options = ClaudeAgentOptions(
                system_prompt=BRON_SYSTEM_PROMPT,
                mcp_servers={"bron": bron_tools},
                allowed_tools=[
                    "Read", "Glob", "Grep", "WebSearch", "WebFetch",
                    "mcp__bron__request_user_input"  # Our custom tool
                ],
                permission_mode="default",
            )
            
            client = ClaudeSDKClient(options=options)
            await client.connect()
            self._sessions[bron_id] = client
            logger.info(f"Created new session for Bron {bron_id} with custom tools")
        
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
        print(f"🔍 SDK available: {session_manager._sdk_available}, bron_id: {bron_id}")
        logger.info(f"🔍 SDK available: {session_manager._sdk_available}, bron_id: {bron_id}")
        if session_manager._sdk_available and bron_id:
            try:
                print("📡 Using SDK client")
                return await self._process_with_sdk_client(
                    user_message, bron_id, task_context
                )
            except Exception as e:
                logger.warning(f"SDK client failed, falling back: {e}")
        
        # Fallback to direct API
        print("📡 Using direct API")
        return await self._process_with_direct_api(
            user_message, task_context, conversation_history
        )

    async def _process_with_sdk_client(
        self,
        user_message: str,
        bron_id: UUID,
        task_context: Optional[dict],
    ) -> AgentResponse:
        """Process message using ClaudeSDKClient with session continuity and custom tools."""
        from claude_agent_sdk import AssistantMessage, TextBlock, ToolUseBlock, ToolResultBlock
        
        client = await session_manager.get_or_create_session(bron_id)
        
        # Build prompt with task context
        prompt = user_message
        if task_context:
            prompt = f"[Task: {task_context.get('title', 'Untitled')} - {task_context.get('state', 'draft')}]\n\n{user_message}"
        
        logger.info(f"📡 SDK: Sending query to Claude for Bron {bron_id}")
        
        # Send query and collect response
        await client.query(prompt)
        
        full_response = []
        ui_recipe = None
        
        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        full_response.append(block.text)
                    elif isinstance(block, ToolUseBlock):
                        logger.info(f"🔧 SDK Tool use: {block.name}")
                        # Check if it's our request_user_input tool
                        if block.name == "mcp__bron__request_user_input" or block.name == "request_user_input":
                            tool_input = block.input
                            logger.info(f"✅ SDK: Claude requested UI Recipe: {tool_input.get('title')}")
                            ui_recipe = UIRecipeSpec(
                                component_type="form",
                                title=tool_input.get("title"),
                                description=tool_input.get("description"),
                                schema_fields=self._convert_fields_to_schema(tool_input.get("fields", {})),
                                required_fields=[
                                    k for k, v in tool_input.get("fields", {}).items()
                                    if isinstance(v, dict) and v.get("required", False)
                                ],
                            )
        
        response_text = "\n".join(full_response) if full_response else "I'm working on that."
        
        # If we got a UI Recipe, return it
        if ui_recipe:
            return AgentResponse(
                intent=AgentIntent.REQUEST_INFO,
                message=response_text or "I need some information to help with this.",
                ui_recipe=ui_recipe
            )
        
        return self._parse_agent_response(response_text)

    def _get_ui_recipe_tool(self) -> dict:
        """Define the tool for requesting structured user input."""
        return {
            "name": "request_user_input",
            "description": "Request structured input from the user via a form. Use this when you need specific information like dates, numbers, choices, or multiple pieces of data.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Title for the input form"
                    },
                    "description": {
                        "type": "string",
                        "description": "Brief explanation of why this info is needed"
                    },
                    "fields": {
                        "type": "object",
                        "description": "Form fields to collect. Each key is a field name, value is an object with type, label, required, placeholder, options (for select)",
                        "additionalProperties": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["text", "number", "date", "datetime", "time", "email", "phone", "url", "select", "boolean", "file", "location", "currency"]
                                },
                                "label": {"type": "string"},
                                "required": {"type": "boolean"},
                                "placeholder": {"type": "string"},
                                "options": {
                                    "type": "array",
                                    "items": {"type": "string"}
                                }
                            },
                            "required": ["type", "label"]
                        }
                    }
                },
                "required": ["title", "fields"]
            }
        }

    async def _process_with_direct_api(
        self,
        user_message: str,
        task_context: Optional[dict],
        conversation_history: Optional[list[dict]],
    ) -> AgentResponse:
        """Fallback using direct Anthropic API with tool use."""
        print("🚀 DIRECT API CALLED - NEW CODE IS RUNNING")
        logger.info("🚀 DIRECT API CALLED - NEW CODE IS RUNNING")
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
            # Determine if this is likely an initial request that needs info gathering
            # If no conversation history, encourage tool use
            should_encourage_tool = len(messages) <= 1
            
            response = await client.messages.create(
                model=settings.claude_model,
                max_tokens=settings.claude_max_tokens,
                system=BRON_SYSTEM_PROMPT,
                messages=messages,
                tools=[self._get_ui_recipe_tool()],
                tool_choice={"type": "any"} if should_encourage_tool else {"type": "auto"},
            )
            
            # Log the raw response for debugging
            logger.info(f"🔍 Claude response stop_reason: {response.stop_reason}")
            logger.info(f"🔍 Claude response content blocks: {len(response.content)}")
            for i, block in enumerate(response.content):
                logger.info(f"🔍 Block {i}: type={block.type}")
            
            # Check if Claude used the tool to request input
            ui_recipe = None
            text_response = ""
            
            for block in response.content:
                if block.type == "text":
                    text_response += block.text
                elif block.type == "tool_use":
                    logger.info(f"🔧 Tool use detected: {block.name}")
                    if block.name == "request_user_input":
                        # Claude wants to collect structured input
                        tool_input = block.input
                        logger.info(f"✅ Claude requested UI Recipe: {tool_input.get('title')}")
                        ui_recipe = UIRecipeSpec(
                            component_type="form",
                            title=tool_input.get("title"),
                            description=tool_input.get("description"),
                            schema_fields=self._convert_fields_to_schema(tool_input.get("fields", {})),
                            required_fields=[
                                k for k, v in tool_input.get("fields", {}).items()
                                if v.get("required", False)
                            ],
                        )
            
            if ui_recipe:
                return AgentResponse(
                    intent=AgentIntent.REQUEST_INFO,
                    message=text_response or f"I need some information to help with this.",
                    ui_recipe=ui_recipe
                )
            
            if text_response:
                return self._parse_agent_response(text_response)
            
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
        """Parse agent response into structured format, extracting UI Recipes if present."""
        import json
        import re
        
        logger.debug(f"Parsing response: {response_text[:500]}...")
        
        # Try to extract UI Recipe JSON from response
        ui_recipe = None
        clean_message = response_text
        
        # Try multiple patterns to find UI Recipe JSON
        patterns = [
            # Pattern 1: ```json { "ui_recipe": ... } ```
            r'```json\s*(\{[\s\S]*?"ui_recipe"[\s\S]*?\})\s*```',
            # Pattern 2: Just JSON block without language tag
            r'```\s*(\{[\s\S]*?"ui_recipe"[\s\S]*?\})\s*```',
            # Pattern 3: Inline JSON (no code blocks)
            r'(\{"ui_recipe":\s*\{[^}]+\}\})',
            # Pattern 4: Multi-line JSON object
            r'(\{[^{]*"ui_recipe"\s*:\s*\{[\s\S]*?\}\s*\})',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, response_text)
            if match:
                try:
                    json_str = match.group(1)
                    logger.info(f"Found potential UI Recipe JSON: {json_str[:200]}...")
                    data = json.loads(json_str)
                    
                    if "ui_recipe" in data:
                        recipe_data = data["ui_recipe"]
                        ui_recipe = UIRecipeSpec(
                            component_type=recipe_data.get("component_type", "form"),
                            title=recipe_data.get("title"),
                            description=recipe_data.get("description"),
                            schema_fields=self._convert_fields_to_schema(recipe_data.get("fields", {})),
                            required_fields=[
                                k for k, v in recipe_data.get("fields", {}).items()
                                if v.get("required", False)
                            ],
                        )
                        logger.info(f"✅ Extracted UI Recipe: {ui_recipe.component_type} - {ui_recipe.title}")
                        # Remove JSON block from message
                        clean_message = response_text[:match.start()] + response_text[match.end():]
                        clean_message = clean_message.strip()
                        break
                except (json.JSONDecodeError, KeyError) as e:
                    logger.warning(f"Failed to parse UI Recipe JSON with pattern: {e}")
                    continue
        
        text_lower = clean_message.lower()
        
        # Detect intent from response
        if ui_recipe:
            intent = AgentIntent.REQUEST_INFO
        elif any(word in text_lower for word in ["done", "complete", "finished", "all set"]):
            intent = AgentIntent.COMPLETE
        elif any(word in text_lower for word in ["shall i", "ready to", "proceed", "execute", "confirm"]):
            intent = AgentIntent.EXECUTE
        elif any(word in text_lower for word in ["error", "failed", "issue", "problem"]):
            intent = AgentIntent.ERROR
        elif any(word in text_lower for word in ["need", "provide", "upload", "share", "what", "which", "?"]):
            intent = AgentIntent.REQUEST_INFO
        else:
            intent = AgentIntent.RESPOND
        
        return AgentResponse(
            intent=intent,
            message=clean_message or response_text,
            ui_recipe=ui_recipe,
        )
    
    def _convert_fields_to_schema(self, fields: dict) -> dict:
        """Convert Claude's field format to our SchemaField format."""
        schema = {}
        for key, field in fields.items():
            schema[key] = {
                "type": field.get("type", "text"),
                "label": field.get("label", key),
                "placeholder": field.get("placeholder"),
                "options": field.get("options"),
            }
        return schema


# Singleton instance
claude_service = ClaudeAgentService()
