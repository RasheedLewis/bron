"""
Claude AI integration service.
Provides deep-agent reasoning via Claude API.
"""

import json
import logging
from typing import Any, Optional
from enum import Enum

from anthropic import AsyncAnthropic, APIError, RateLimitError, APIConnectionError
from pydantic import BaseModel, Field

from app.core.config import settings

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
    reasoning: Optional[str] = None  # Internal reasoning (not shown to user)


# ============================================================================
# Prompt Templates
# ============================================================================

SYSTEM_PROMPT = """You are Bron, a personal AI agent that helps users accomplish tasks efficiently.

## Your Core Principles
1. **Be proactive**: Break tasks into actionable steps
2. **Be efficient**: Only ask for information when truly needed
3. **Be safe**: Never perform destructive actions without explicit approval
4. **Be clear**: Communicate status and next steps clearly

## How You Work
- You receive tasks from users and work on them in the background
- When you need information, generate a UI Recipe to collect it
- You can update task state as you make progress
- You must get explicit approval before executing any external action

## Response Format
You MUST respond with valid JSON in this exact format:
```json
{
  "intent": "respond|request_info|update_task|execute|complete|error",
  "message": "Your message to the user",
  "reasoning": "Your internal reasoning (optional)",
  "ui_recipe": {
    "component_type": "form|picker|confirmation|...",
    "title": "Title for the UI",
    "description": "Description",
    "schema_fields": {
      "field_name": {
        "type": "text|number|date|email|...",
        "label": "Field Label",
        "placeholder": "Placeholder text",
        "options": ["option1", "option2"]
      }
    },
    "required_fields": ["field_name"],
    "style_preset": "google|apple|email|..."
  },
  "task_update": {
    "new_state": "draft|needs_info|planned|ready|executing|done|failed",
    "progress": 0.5,
    "next_action": "What needs to happen next",
    "waiting_on": "What we're waiting for"
  }
}
```

## UI Recipe Component Types
INPUT: form, picker, multi_select, date_picker, contact_picker, file_upload, location_picker
DISPLAY: info_card, weather, summary, list_view, progress
ACTION: confirmation, approval, auth_google, auth_apple, auth_oauth, execute
RICH: email_preview, email_compose, calendar_event, message_preview, document_preview, link_preview

## Style Presets
google, apple, microsoft, github, slack, notion, spotify
professional, casual, urgent, success, warning, error
email, calendar, weather, financial, health

## Safety Rules (NEVER VIOLATE)
1. NEVER delete files, data, or accounts
2. NEVER send messages/emails without explicit user approval
3. NEVER share sensitive information
4. NEVER execute financial transactions without approval
5. ALWAYS use "confirmation" or "approval" UI before destructive/external actions
"""

TASK_CONTEXT_TEMPLATE = """
## Current Task
Title: {title}
Description: {description}
State: {state}
Category: {category}
Progress: {progress}%
Next Action: {next_action}
Waiting On: {waiting_on}

## Conversation History
{history}

## User's Latest Message
{user_message}

Respond with your JSON action.
"""


# ============================================================================
# Claude Service
# ============================================================================

class ClaudeService:
    """
    Service for interacting with Claude API.
    
    Provides:
    - Task-aware conversation with Claude
    - UI Recipe generation
    - Response parsing with validation
    - Error handling with retries
    - Safety guardrails
    """

    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.model = settings.claude_model
        self.max_tokens = settings.claude_max_tokens
        self.max_retries = 3

    async def process_message(
        self,
        user_message: str,
        task_context: Optional[dict] = None,
        conversation_history: Optional[list[dict]] = None,
        user_preferences: Optional[dict] = None,
    ) -> AgentResponse:
        """
        Process a user message and generate an agent response.
        
        Args:
            user_message: The user's input message
            task_context: Current task information (title, state, etc.)
            conversation_history: Previous messages in the conversation
            user_preferences: User's personalization preferences
            
        Returns:
            AgentResponse with intent, message, and optional UI recipe/task update
        """
        # Build the prompt
        prompt = self._build_prompt(
            user_message=user_message,
            task_context=task_context,
            conversation_history=conversation_history,
        )
        
        # Build system prompt with personalization
        system = self._build_system_prompt(user_preferences)
        
        # Call Claude with retries
        response_text = await self._call_claude_with_retry(
            messages=[{"role": "user", "content": prompt}],
            system=system,
        )
        
        # Parse and validate response
        agent_response = self._parse_response(response_text)
        
        # Apply safety guardrails
        agent_response = self._apply_safety_guardrails(agent_response)
        
        return agent_response

    async def generate_ui_recipe(
        self,
        task_context: dict,
        missing_info: list[str],
        preferred_style: Optional[str] = None,
    ) -> UIRecipeSpec:
        """
        Generate a UI Recipe for collecting specific information.
        
        Args:
            task_context: Current task information
            missing_info: List of information items needed
            preferred_style: Optional style preset to use
            
        Returns:
            UIRecipeSpec for the generated UI
        """
        prompt = f"""
Generate a UI Recipe to collect the following information for this task:

Task: {task_context.get('title', 'Unknown')}
Description: {task_context.get('description', 'No description')}

Information needed:
{chr(10).join(f'- {info}' for info in missing_info)}

{"Use style preset: " + preferred_style if preferred_style else "Choose an appropriate style preset based on the task context."}

Respond with ONLY the ui_recipe JSON object.
"""
        
        response_text = await self._call_claude_with_retry(
            messages=[{"role": "user", "content": prompt}],
            system=SYSTEM_PROMPT,
        )
        
        # Parse UI Recipe from response
        try:
            data = json.loads(response_text)
            if "ui_recipe" in data:
                data = data["ui_recipe"]
            return UIRecipeSpec(**data)
        except (json.JSONDecodeError, ValueError) as e:
            logger.error(f"Failed to parse UI Recipe: {e}")
            # Return a fallback form
            return UIRecipeSpec(
                component_type="form",
                title="Information Needed",
                description="Please provide the following information:",
                schema_fields={
                    info.lower().replace(" ", "_"): {
                        "type": "text",
                        "label": info,
                    }
                    for info in missing_info
                },
                required_fields=[info.lower().replace(" ", "_") for info in missing_info],
            )

    async def analyze_task(
        self,
        task_description: str,
        user_context: Optional[dict] = None,
    ) -> dict:
        """
        Analyze a task and generate a plan.
        
        Args:
            task_description: Description of what the user wants to accomplish
            user_context: Optional context about the user
            
        Returns:
            Dictionary with task analysis (category, steps, required info, etc.)
        """
        prompt = f"""
Analyze this task and provide a structured plan:

Task: {task_description}

Respond with JSON containing:
{{
  "category": "admin|creative|school|personal|work|other",
  "complexity": "simple|moderate|complex",
  "steps": ["Step 1", "Step 2", ...],
  "required_info": ["Info item 1", "Info item 2", ...],
  "estimated_interactions": 1-10,
  "can_start_immediately": true|false,
  "first_action": "Description of first action"
}}
"""
        
        response_text = await self._call_claude_with_retry(
            messages=[{"role": "user", "content": prompt}],
            system=SYSTEM_PROMPT,
        )
        
        try:
            return json.loads(response_text)
        except json.JSONDecodeError:
            return {
                "category": "other",
                "complexity": "moderate",
                "steps": ["Analyze task", "Gather information", "Execute"],
                "required_info": [],
                "estimated_interactions": 3,
                "can_start_immediately": False,
                "first_action": "Understand the task requirements",
            }

    # ========================================================================
    # Private Methods
    # ========================================================================

    def _build_prompt(
        self,
        user_message: str,
        task_context: Optional[dict],
        conversation_history: Optional[list[dict]],
    ) -> str:
        """Build the prompt for Claude."""
        if task_context:
            history_str = ""
            if conversation_history:
                for msg in conversation_history[-10:]:  # Last 10 messages
                    role = "User" if msg.get("role") == "user" else "Bron"
                    history_str += f"{role}: {msg.get('content', '')}\n"
            
            return TASK_CONTEXT_TEMPLATE.format(
                title=task_context.get("title", "No title"),
                description=task_context.get("description", "No description"),
                state=task_context.get("state", "draft"),
                category=task_context.get("category", "other"),
                progress=int(task_context.get("progress", 0) * 100),
                next_action=task_context.get("next_action", "None"),
                waiting_on=task_context.get("waiting_on", "Nothing"),
                history=history_str or "No previous messages",
                user_message=user_message,
            )
        else:
            return f"User message: {user_message}\n\nRespond with your JSON action."

    def _build_system_prompt(self, user_preferences: Optional[dict]) -> str:
        """Build system prompt with personalization."""
        base = SYSTEM_PROMPT
        
        if user_preferences:
            tone = user_preferences.get("tone", "balanced")
            base += f"\n\n## User Preferences\n- Communication tone: {tone}"
            
            if user_preferences.get("concise"):
                base += "\n- Keep responses concise and to the point"
            
            if user_preferences.get("detailed"):
                base += "\n- Provide detailed explanations when helpful"
        
        return base

    async def _call_claude_with_retry(
        self,
        messages: list[dict],
        system: str,
    ) -> str:
        """Call Claude API with retry logic."""
        last_error = None
        
        for attempt in range(self.max_retries):
            try:
                response = await self.client.messages.create(
                    model=self.model,
                    max_tokens=self.max_tokens,
                    system=system,
                    messages=messages,
                )
                
                # Extract text content
                if response.content and len(response.content) > 0:
                    return response.content[0].text
                
                raise ValueError("Empty response from Claude")
                
            except RateLimitError as e:
                logger.warning(f"Rate limited (attempt {attempt + 1}): {e}")
                last_error = e
                # Exponential backoff
                import asyncio
                await asyncio.sleep(2 ** attempt)
                
            except APIConnectionError as e:
                logger.warning(f"Connection error (attempt {attempt + 1}): {e}")
                last_error = e
                import asyncio
                await asyncio.sleep(1)
                
            except APIError as e:
                logger.error(f"API error: {e}")
                last_error = e
                break  # Don't retry on API errors
        
        # All retries failed
        raise last_error or Exception("Failed to call Claude API")

    def _parse_response(self, response_text: str) -> AgentResponse:
        """Parse Claude's response into structured format."""
        # Try to extract JSON from the response
        try:
            # Handle markdown code blocks
            if "```json" in response_text:
                start = response_text.find("```json") + 7
                end = response_text.find("```", start)
                response_text = response_text[start:end].strip()
            elif "```" in response_text:
                start = response_text.find("```") + 3
                end = response_text.find("```", start)
                response_text = response_text[start:end].strip()
            
            data = json.loads(response_text)
            
            # Parse intent
            intent = AgentIntent(data.get("intent", "respond"))
            
            # Parse UI Recipe if present
            ui_recipe = None
            if data.get("ui_recipe"):
                ui_recipe = UIRecipeSpec(**data["ui_recipe"])
            
            # Parse task update if present
            task_update = None
            if data.get("task_update"):
                task_update = TaskStateUpdate(**data["task_update"])
            
            return AgentResponse(
                intent=intent,
                message=data.get("message", ""),
                ui_recipe=ui_recipe,
                task_update=task_update,
                reasoning=data.get("reasoning"),
            )
            
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"Failed to parse JSON response: {e}")
            # Return raw response as message
            return AgentResponse(
                intent=AgentIntent.RESPOND,
                message=response_text,
            )

    def _apply_safety_guardrails(self, response: AgentResponse) -> AgentResponse:
        """
        Apply safety guardrails to the response.
        
        Ensures no destructive actions are taken without approval.
        """
        # List of dangerous keywords that require confirmation
        dangerous_keywords = [
            "delete", "remove", "erase", "destroy",
            "send", "email", "message", "post", "publish",
            "pay", "transfer", "purchase", "buy",
            "cancel", "unsubscribe", "terminate",
        ]
        
        message_lower = response.message.lower()
        
        # Check if response mentions dangerous actions
        has_dangerous_action = any(
            keyword in message_lower for keyword in dangerous_keywords
        )
        
        # If intent is EXECUTE and there's a dangerous action, require approval
        if response.intent == AgentIntent.EXECUTE and has_dangerous_action:
            if not response.ui_recipe or response.ui_recipe.component_type not in [
                "confirmation", "approval"
            ]:
                # Force approval UI
                response.ui_recipe = UIRecipeSpec(
                    component_type="approval",
                    title="Action Requires Approval",
                    description=response.message,
                    style_preset="warning",
                )
                response.intent = AgentIntent.REQUEST_INFO
                response.message = "This action requires your approval before I can proceed."
        
        return response


# Singleton instance
claude_service = ClaudeService()
