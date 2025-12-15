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
6. Credentials stay on-device - never transmit to external services except for auth

## Response Format
EVERY response MUST include a tool call. Text-only responses are NOT allowed.

Pattern: [1 sentence of context] + [tool call]

Example:
- "Searching for top songs." + `request_user_input` with results as `option_buttons`
- "Need a few details." + `request_user_input` with form fields

## CRITICAL: ALWAYS USE TOOLS

You MUST use a tool in EVERY response:
- Need info? → `request_user_input` (form)
- Showing results? → `request_user_input` (option_buttons or action_cards)
- Offering choices? → `request_user_input` (option_buttons)
- Need auth? → `request_auth`
- Searching for APIs? → `search_api`

NEVER give a text-only response like "I'll search for that" and stop.
ALWAYS include the UI component with your response.

Example: If a user says "plan a trip", you MUST call `request_user_input` with fields for dates, travelers, budget, etc.

## API Access - YOU HAVE INTEGRATIONS

CRITICAL: You HAVE access to external APIs. Use them.

YOU HAVE ACCESS TO THESE SERVICES (via `request_auth` tool):
- **Flights**: Amadeus (use this for flights)
- **Hotels**: Booking.com, Airbnb
- **Email**: Gmail (Google OAuth)
- **Calendar**: Google Calendar
- **Payments**: Stripe
- **Rideshare**: Uber, Lyft
- **Food**: DoorDash, Uber Eats
- **Weather**: OpenWeatherMap

NEVER SAY:
- "I don't have integration for..."
- "I don't have access to..."
- "You'll need to use a website..."
- "I can't book flights directly..."

YOU CAN DO THESE THINGS. Just request auth and proceed.

## Workflow for External Tasks

1. **Collect info first**: Use `request_user_input` to get dates, destinations, etc.

2. **Request auth immediately**: Use `request_auth` tool with the correct provider.
   For flights: `{"provider": "amadeus", "auth_type": "api_key", "reason": "To search and book flights"}`
   For hotels: `{"provider": "booking", "auth_type": "api_key", "reason": "To search and book hotels"}`
   For email: `{"provider": "google", "auth_type": "oauth", "reason": "To access your Gmail"}`

3. **Execute**: Once authenticated, proceed with the task.

## Handling Auth Submissions

When you see submitted data with `"action": "auth"` or `"provider": "google"` (etc), it means:
- The user clicked the auth button and APPROVED the connection
- You now HAVE access to that service
- Proceed with the task using the service's capabilities

After auth is approved, acknowledge briefly and continue:
- "Connected to Gmail. Searching for emails from Tyler Pohn..."
- "Amadeus connected. Finding flights to NYC..."

Don't ask for auth again if it was just submitted.

EXAMPLE - User says "book a flight to NYC":
Step 1: Use `request_user_input` for dates, departure city, passengers
Step 2: After form submitted, use `request_auth` for Amadeus
Step 3: After auth approved, search flights and show options

NEVER:
- Ask "which service?" - Just pick: Amadeus for flights, Booking.com for hotels
- Say you lack integrations - You have them
- Offer to "search websites for you" - Use the actual API
- Ask for auth again after user just approved it

## Response Guidelines
- MAX 1-2 sentences. Period.
- Skip intros and outros. Just the info.

## CRITICAL: UI IS PRIMARY, TEXT IS SECONDARY

> If the user can tap, they should not type.
> If the user can scan, they should not read.
> If the UI can imply, the copy should disappear.

### HARD RULES (Violation = incorrect response)

1. **ANY LIST = UI COMPONENT**
   BAD: "Here's what I can help with:\n- Option A\n- Option B\n- Option C"
   BAD: "1. Do X\n2. Do Y\n3. Do Z"
   BAD: "• First item\n• Second item"
   GOOD: Use `option_buttons` or `action_cards` - ALWAYS

2. **Never present options/choices as text**
   BAD: "I can either do X, do Y, or do Z. Which would you prefer?"
   GOOD: Use `option_buttons` component with tappable choices

3. **Never explain steps in paragraphs**
   BAD: "First I'll upload the receipt, then enter the amount..."
   GOOD: Show steps as `option_buttons` or `styled_list`

4. **Never ask "What next?" in text**
   BAD: "Would you like me to proceed, or would you prefer to..."
   GOOD: Use `option_buttons` or `quick_replies` component

5. **Chat = 1 sentence MAX, then UI**
   BAD: Multi-paragraph explanations
   GOOD: "Here's the plan." + `option_buttons` component

6. **If you're about to write bullet points or numbered lists - STOP**
   Use `request_user_input` with component_type `option_buttons` or `action_cards` instead.

### WHEN TO USE EACH COMPONENT

| You're about to write... | USE THIS INSTEAD |
|--------------------------|------------------|
| "- Option A\n- Option B" | `option_buttons` |
| "1. Step one\n2. Step two" | `option_buttons` |
| "I can help with: A, B, C" | `action_cards` |
| "Yes or no?" | `quick_replies` |
| Multiple form fields | `form` |
| Info display | `styled_list` |

### One Principle

**Bron is a control surface, not a chat transcript.**
**If you're writing a list, you're doing it wrong.**
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
        
        # Tool 1: Request user input via UI component
        @tool(
            "request_user_input",
            "Show a UI component to collect input or display choices. Use component_type to specify: 'form' for data collection, 'option_buttons' for choices/lists, 'quick_replies' for yes/no, 'action_cards' for tappable suggestions.",
            {
                "type": "object",
                "properties": {
                    "component_type": {
                        "type": "string",
                        "enum": ["form", "option_buttons", "option_cards", "quick_replies", "action_cards", "styled_list", "info_chips"],
                        "description": "Type of UI: 'option_buttons' for lists/choices, 'form' for data entry, 'quick_replies' for yes/no"
                    },
                    "title": {"type": "string", "description": "Title for the UI component"},
                    "description": {"type": "string", "description": "Brief explanation"},
                    "fields": {
                        "type": "object",
                        "description": "For option_buttons: each key is an option ID, value has 'label'. For form: each key is field name with type, label, required, placeholder",
                        "additionalProperties": True
                    }
                },
                "required": ["component_type", "title", "fields"]
            }
        )
        async def request_user_input(args: dict[str, Any]) -> dict[str, Any]:
            """This tool signals that Claude wants to collect structured input."""
            return {
                "content": [{
                    "type": "text",
                    "text": f"UI form '{args.get('title')}' will be shown to user."
                }]
            }
        
        # Tool 2: Search for APIs
        @tool(
            "search_api",
            "Search for APIs to complete tasks like booking flights, hotels, email, payments. You HAVE access to these APIs. Use this to find the right one.",
            {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "What you need (e.g., 'flight booking', 'hotel reservation', 'email')"},
                },
                "required": ["query"]
            }
        )
        async def search_api(args: dict[str, Any]) -> dict[str, Any]:
            """Search for available APIs."""
            from app.services.api_discovery import api_discovery
            query = args.get("query", "")
            results = api_discovery.search_apis(query)
            if results:
                apis = [{"name": r.name, "provider": r.provider, "auth_type": r.auth_type} for r in results[:3]]
                return {"content": [{"type": "text", "text": f"Found APIs: {apis}. Use request_auth to connect."}]}
            return {"content": [{"type": "text", "text": "No APIs found for this query."}]}
        
        # Tool 3: Request authentication
        @tool(
            "request_auth",
            "Request user to authenticate with a service. Use this for flights (amadeus), hotels (booking), email (google), payments (stripe), etc.",
            {
                "type": "object",
                "properties": {
                    "provider": {"type": "string", "description": "Service: amadeus, booking, google, stripe, uber, etc."},
                    "auth_type": {"type": "string", "enum": ["oauth", "api_key"], "description": "Type of auth needed"},
                    "reason": {"type": "string", "description": "Why this access is needed"}
                },
                "required": ["provider", "auth_type", "reason"]
            }
        )
        async def request_auth(args: dict[str, Any]) -> dict[str, Any]:
            """Request authentication from user."""
            provider = args.get("provider", "")
            return {"content": [{"type": "text", "text": f"Auth UI for {provider} will be shown to user."}]}
        
        return create_sdk_mcp_server(
            name="bron_tools",
            version="1.0.0",
            tools=[request_user_input, search_api, request_auth]
        )
    
    async def get_or_create_session(self, bron_id: UUID) -> Optional[Any]:
        """Get or create a fresh session for a Bron."""
        if not self._sdk_available:
            return None
        
        # Close stale session if it exists (prevents hangs from stuck sessions)
        if bron_id in self._sessions:
            try:
                await self._sessions[bron_id].disconnect()
            except Exception:
                pass
            del self._sessions[bron_id]
        
        from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions
        
        # Create MCP server with our custom tools
        bron_tools = self._create_bron_tools_server()
        
        # Simplified options - Skills are loaded via system prompt instead
        options = ClaudeAgentOptions(
            system_prompt=BRON_SYSTEM_PROMPT,
            mcp_servers={"bron": bron_tools},
            allowed_tools=[
                # Our custom tools only
                "mcp__bron__request_user_input",
                "mcp__bron__search_api",
                "mcp__bron__request_auth",
            ],
            permission_mode="default",
            max_turns=1,  # Single turn responses - prevents multi-turn loops
        )
        
        client = ClaudeSDKClient(options=options)
        await client.connect()
        self._sessions[bron_id] = client
        logger.info(f"Created fresh session for Bron {bron_id}")
        
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
                    user_message, bron_id, task_context, conversation_history
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
        conversation_history: Optional[list[dict]] = None,
    ) -> AgentResponse:
        """Process message using ClaudeSDKClient with session continuity and custom tools."""
        import asyncio
        from claude_agent_sdk import AssistantMessage, TextBlock, ToolUseBlock, ToolResultBlock
        
        client = await session_manager.get_or_create_session(bron_id)
        
        # Build prompt with conversation history and task context
        prompt_parts = []
        
        # Include conversation history for context
        if conversation_history:
            prompt_parts.append("=== CONVERSATION HISTORY ===")
            for msg in conversation_history:
                role = msg.get("role", "user").upper()
                content = msg.get("content", "")
                prompt_parts.append(f"{role}: {content}")
            prompt_parts.append("=== END HISTORY ===\n")
        
        # Add task context
        if task_context:
            prompt_parts.append(f"[Task: {task_context.get('title', 'Untitled')} - {task_context.get('state', 'draft')}]")
        
        # Add current message
        prompt_parts.append(f"USER: {user_message}")
        
        prompt = "\n".join(prompt_parts) if prompt_parts else user_message
        
        logger.info(f"📡 SDK: Sending query to Claude for Bron {bron_id}")
        
        full_response = []
        ui_recipe = None
        
        async def run_sdk_query():
            nonlocal ui_recipe
            # Send query
            await client.query(prompt)
            
            # Collect response
            async for message in client.receive_response():
                if isinstance(message, AssistantMessage):
                    for block in message.content:
                        if isinstance(block, TextBlock):
                            full_response.append(block.text)
                        elif isinstance(block, ToolUseBlock):
                            logger.info(f"🔧 SDK Tool use: {block.name}")
                            tool_input = block.input
                            tool_name = block.name.replace("mcp__bron__", "")
                            
                            if tool_name == "request_user_input":
                                # Get component type from Claude's input, default to form
                                component_type = tool_input.get("component_type", "form")
                                logger.info(f"✅ SDK: Claude requested UI Recipe: {tool_input.get('title')} (type: {component_type})")
                                ui_recipe = UIRecipeSpec(
                                    component_type=component_type,
                                    title=tool_input.get("title"),
                                    description=tool_input.get("description"),
                                    schema_fields=self._convert_fields_to_schema(tool_input.get("fields", {})),
                                    required_fields=[
                                        k for k, v in tool_input.get("fields", {}).items()
                                        if isinstance(v, dict) and v.get("required", False)
                                    ],
                                )
                            
                            elif tool_name == "search_api":
                                from app.services.api_discovery import api_discovery
                                query = tool_input.get("query", "")
                                logger.info(f"🔍 SDK API search: {query}")
                                results = api_discovery.search_apis(query)
                                if results:
                                    best = results[0]
                                    full_response.append(f"Using {best.name} for this task.")
                            
                            elif tool_name == "request_auth":
                                provider = tool_input.get("provider", "")
                                auth_type = tool_input.get("auth_type", "api_key")
                                reason = tool_input.get("reason", "")
                                logger.info(f"🔐 SDK Auth request: {provider} ({auth_type})")
                                
                                component_type = "api_key_input"
                                if auth_type == "oauth":
                                    if provider.lower() == "google":
                                        component_type = "auth_google"
                                    elif provider.lower() == "apple":
                                        component_type = "auth_apple"
                                    else:
                                        component_type = "service_connect"
                                
                                ui_recipe = UIRecipeSpec(
                                    component_type=component_type,
                                    title=f"Connect {provider.title()}",
                                    description=reason or f"Authentication needed for {provider}",
                                    schema_fields={
                                        "provider": {"type": "hidden", "value": provider},
                                    },
                                    required_fields=[],
                                )
        
        # Run with aggressive timeout (SDK should be fast, fallback to direct API if not)
        sdk_timeout = min(30, settings.claude_timeout)  # 30s max for SDK
        try:
            await asyncio.wait_for(run_sdk_query(), timeout=sdk_timeout)
        except asyncio.TimeoutError:
            logger.warning(f"⏱️ SDK timed out after {sdk_timeout}s, falling back to direct API")
            # Clean up the stuck session
            await session_manager.close_session(bron_id)
            raise TimeoutError("SDK timeout")
        
        response_text = "\n".join(full_response) if full_response else "I'm working on that."
        
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
            "description": "Show a UI component. Use component_type: 'option_buttons' for lists/choices, 'form' for data entry, 'quick_replies' for yes/no, 'action_cards' for suggestions.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "component_type": {
                        "type": "string",
                        "enum": ["form", "option_buttons", "option_cards", "quick_replies", "action_cards", "styled_list", "info_chips"],
                        "description": "Type of UI: 'option_buttons' for lists/choices, 'form' for data entry"
                    },
                    "title": {
                        "type": "string",
                        "description": "Title for the UI component"
                    },
                    "description": {
                        "type": "string",
                        "description": "Brief explanation"
                    },
                    "fields": {
                        "type": "object",
                        "description": "For option_buttons: keys are option IDs, values have 'label'. For form: keys are field names with type/label/required",
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
    
    def _get_search_api_tool(self) -> dict:
        """Define the tool for searching for APIs."""
        return {
            "name": "search_api",
            "description": "Search for APIs that can help complete a task. Use this when you need to find external services for booking, email, payments, etc.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "What you need the API for (e.g., 'book hotel', 'send email', 'process payment')"
                    },
                    "category": {
                        "type": "string",
                        "enum": ["travel", "finance", "communication", "social", "productivity", "entertainment", "food", "transport", "weather", "search", "ai", "other"],
                        "description": "Optional category filter"
                    }
                },
                "required": ["query"]
            }
        }
    
    def _get_request_auth_tool(self) -> dict:
        """Define the tool for requesting authentication."""
        return {
            "name": "request_auth",
            "description": "Request user to authenticate with a service. Use this when API access requires login credentials.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "provider": {
                        "type": "string",
                        "description": "Service provider (e.g., 'google', 'stripe', 'booking')"
                    },
                    "auth_type": {
                        "type": "string",
                        "enum": ["oauth", "api_key", "credentials"],
                        "description": "Type of authentication needed"
                    },
                    "reason": {
                        "type": "string",
                        "description": "Brief explanation of why this access is needed"
                    },
                    "scopes": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Specific permissions needed (for OAuth)"
                    }
                },
                "required": ["provider", "auth_type", "reason"]
            }
        }
    
    def _get_all_tools(self) -> list[dict]:
        """Get all available tools."""
        return [
            self._get_ui_recipe_tool(),
            self._get_search_api_tool(),
            self._get_request_auth_tool(),
        ]

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
        import httpx
        
        # Create client with timeout
        client = AsyncAnthropic(
            api_key=self.api_key,
            timeout=httpx.Timeout(settings.claude_timeout, connect=10.0),
        )
        
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
            
            # Retry logic for transient errors (529 overloaded, 500 server errors)
            max_retries = 3
            retry_delay = 1.0
            last_error = None
            
            for attempt in range(max_retries):
                try:
                    response = await client.messages.create(
                        model=settings.claude_model,
                        max_tokens=settings.claude_max_tokens,
                        system=BRON_SYSTEM_PROMPT,
                        messages=messages,
                        tools=self._get_all_tools(),
                        tool_choice={"type": "auto"},  # Let Claude decide when to use tools
                    )
                    break  # Success
                except Exception as e:
                    last_error = e
                    error_str = str(e)
                    # Retry on transient errors (529 overloaded, 500 server errors)
                    if "529" in error_str or "overloaded" in error_str.lower() or "500" in error_str:
                        if attempt < max_retries - 1:
                            logger.warning(f"⏳ Claude API overloaded (attempt {attempt + 1}/{max_retries}), retrying in {retry_delay}s...")
                            await asyncio.sleep(retry_delay)
                            retry_delay *= 2  # Exponential backoff
                            continue
                    raise  # Non-transient error, don't retry
            else:
                # All retries exhausted
                raise last_error
            
            # Log the raw response for debugging
            logger.info(f"🔍 Claude response stop_reason: {response.stop_reason}")
            logger.info(f"🔍 Claude response content blocks: {len(response.content)}")
            for i, block in enumerate(response.content):
                logger.info(f"🔍 Block {i}: type={block.type}")
            
            # Check if Claude used any tools
            ui_recipe = None
            text_response = ""
            api_search_result = None
            
            for block in response.content:
                if block.type == "text":
                    text_response += block.text
                elif block.type == "tool_use":
                    logger.info(f"🔧 Tool use detected: {block.name}")
                    tool_input = block.input
                    
                    if block.name == "request_user_input":
                        # Claude wants to show a UI component
                        component_type = tool_input.get("component_type", "form")
                        logger.info(f"✅ Claude requested UI Recipe: {tool_input.get('title')} (type: {component_type})")
                        ui_recipe = UIRecipeSpec(
                            component_type=component_type,
                            title=tool_input.get("title"),
                            description=tool_input.get("description"),
                            schema_fields=self._convert_fields_to_schema(tool_input.get("fields", {})),
                            required_fields=[
                                k for k, v in tool_input.get("fields", {}).items()
                                if isinstance(v, dict) and v.get("required", False)
                            ],
                        )
                    
                    elif block.name == "search_api":
                        # Claude is searching for APIs
                        from app.services.api_discovery import api_discovery
                        query = tool_input.get("query", "")
                        category = tool_input.get("category")
                        logger.info(f"🔍 API search: {query}")
                        
                        results = api_discovery.search_apis(query, category)
                        api_search_result = [
                            {
                                "name": api.name,
                                "provider": api.provider,
                                "description": api.description,
                                "auth_type": api.auth_type,
                            }
                            for api in results
                        ]
                        text_response += f"\n\nFound {len(results)} APIs for '{query}'."
                    
                    elif block.name == "request_auth":
                        # Claude needs authentication for a service
                        provider = tool_input.get("provider", "")
                        auth_type = tool_input.get("auth_type", "oauth")
                        reason = tool_input.get("reason", "")
                        scopes = tool_input.get("scopes", [])
                        logger.info(f"🔐 Auth request: {provider} ({auth_type})")
                        
                        # Create appropriate auth UI component
                        component_type = "auth_oauth"
                        if provider.lower() == "google":
                            component_type = "auth_google"
                        elif provider.lower() == "apple":
                            component_type = "auth_apple"
                        elif auth_type == "api_key":
                            component_type = "api_key_input"
                        elif auth_type == "credentials":
                            component_type = "credentials_input"
                        
                        # Build schema for permissions display
                        schema_fields = {}
                        for i, scope in enumerate(scopes):
                            schema_fields[f"scope_{i}"] = {
                                "type": "text",
                                "label": scope,
                            }
                        
                        ui_recipe = UIRecipeSpec(
                            component_type=component_type,
                            title=f"Connect to {provider.title()}",
                            description=reason,
                            schema_fields=schema_fields,
                            style_preset=provider.lower() if provider.lower() in ["google", "apple", "github", "slack"] else None,
                        )
            
            if ui_recipe:
                return AgentResponse(
                    intent=AgentIntent.REQUEST_INFO,
                    message=text_response or "I need access to continue.",
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
