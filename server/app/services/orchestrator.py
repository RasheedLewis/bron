"""
Task Orchestration Service.
Coordinates between Claude, tasks, and the chat system.
"""

import logging
from typing import Optional
from uuid import UUID

from sqlalchemy import select

logger = logging.getLogger(__name__)
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    BronInstance, BronStatus,
    Task, TaskState, TaskCategory,
    ChatMessage, MessageRole,
    UIRecipe, UIComponentType, UIStyle, UIStylePreset,
)
from app.services.claude import (
    claude_service,
    AgentResponse,
    AgentIntent,
    UIRecipeSpec,
)

logger = logging.getLogger(__name__)


class TaskOrchestrator:
    """
    Orchestrates task execution with Claude.
    
    Responsibilities:
    - Process user messages through Claude
    - Create and update tasks based on Claude's analysis
    - Generate UI Recipes for information collection
    - Manage task state transitions
    - Store conversation history
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def process_user_message(
        self,
        bron_id: UUID,
        message_content: str,
    ) -> ChatMessage:
        """
        Process a user message and generate a response.
        
        Args:
            bron_id: ID of the Bron agent
            message_content: The user's message
            
        Returns:
            The assistant's response message
        """
        # Get the Bron and current task
        bron = await self._get_bron(bron_id)
        if not bron:
            raise ValueError(f"Bron not found: {bron_id}")
        
        # Get current task context
        task = await self._get_current_task(bron)
        task_context = self._build_task_context(task) if task else None
        
        # Get conversation history
        history = await self._get_conversation_history(bron_id, limit=10)
        
        # Store user message
        user_message = ChatMessage(
            bron_id=bron_id,
            role=MessageRole.USER,
            content=message_content,
        )
        self.db.add(user_message)
        await self.db.flush()
        
        # Process with Claude (pass bron_id for session continuity)
        try:
            agent_response = await claude_service.process_message(
                user_message=message_content,
                bron_id=bron_id,
                task_context=task_context,
                conversation_history=history,
            )
        except Exception as e:
            logger.error(f"Claude processing failed: {e}")
            # Create error response
            return await self._create_error_response(bron_id, str(e))
        
        # Handle the response based on intent
        assistant_message = await self._handle_agent_response(
            bron=bron,
            task=task,
            response=agent_response,
        )
        
        return assistant_message

    async def create_task_from_message(
        self,
        bron_id: UUID,
        message_content: str,
    ) -> tuple[Task, ChatMessage]:
        """
        Analyze a message and create a new task.
        
        Args:
            bron_id: ID of the Bron agent
            message_content: The message describing the task
            
        Returns:
            Tuple of (created task, assistant response)
        """
        bron = await self._get_bron(bron_id)
        if not bron:
            raise ValueError(f"Bron not found: {bron_id}")
        
        # Get conversation history BEFORE storing current message
        history = await self._get_conversation_history(bron_id, limit=10)
        
        # Store user message
        user_message = ChatMessage(
            bron_id=bron_id,
            role=MessageRole.USER,
            content=message_content,
        )
        self.db.add(user_message)
        await self.db.flush()
        
        # Get Claude's response with conversation context and session
        agent_response = await claude_service.process_message(
            user_message=message_content,
            bron_id=bron_id,
            conversation_history=history,
        )
        analysis = {
            "category": self._detect_category(message_content),
            "response": agent_response.message,
        }
        
        # Generate a concise title for the task
        task_title = self._generate_task_title(message_content)
        
        # Create the task
        task = Task(
            title=task_title,
            description=message_content,
            state=TaskState.DRAFT,
            category=TaskCategory(analysis.get("category", "other")),
            bron_id=bron_id,
            progress=0.0,
        )
        self.db.add(task)
        
        # Update Bron's current task
        bron.current_task_id = task.id
        bron.status = BronStatus.WORKING
        
        # Only update name if it's the default (first task)
        if bron.name in ("New Bron", "Bron", None, ""):
            bron.name = task_title
        
        await self.db.flush()
        
        # Use Claude's actual response
        task.state = TaskState.PLANNED
        
        # If Claude requested info via UI Recipe, set task to NEEDS_INFO
        if agent_response.ui_recipe:
            task.state = TaskState.NEEDS_INFO
            if agent_response.ui_recipe.title:
                task.waiting_on = agent_response.ui_recipe.title
        
        task_state_str = task.state.value if hasattr(task.state, 'value') else task.state
        response = ChatMessage(
            bron_id=bron_id,
            role=MessageRole.ASSISTANT,
            content=analysis.get("response", "I'm on it."),
            task_state_update=task_state_str,
        )
        self.db.add(response)
        await self.db.flush()
        await self.db.refresh(response)
        
        # Create UI Recipe if Claude requested one
        if agent_response.ui_recipe:
            await self._create_ui_recipe(
                task_id=task.id,
                spec=agent_response.ui_recipe,
                message_id=response.id,
            )
            logger.info(f"✅ Created UI Recipe: {agent_response.ui_recipe.title}")
        
        return task, response

    async def handle_ui_recipe_submission(
        self,
        recipe_id: UUID,
        submitted_data: dict,
    ) -> ChatMessage:
        """
        Handle submission of UI Recipe data.
        
        Args:
            recipe_id: ID of the UI Recipe
            submitted_data: The data submitted by the user
            
        Returns:
            The assistant's response message
        """
        # Get the UI Recipe with eager loading
        from sqlalchemy.orm import selectinload
        result = await self.db.execute(
            select(UIRecipe)
            .options(selectinload(UIRecipe.task), selectinload(UIRecipe.message))
            .where(UIRecipe.id == recipe_id)
        )
        recipe = result.scalar_one_or_none()
        
        if not recipe:
            raise ValueError(f"UI Recipe not found: {recipe_id}")
        
        # Mark as submitted
        recipe.submitted_data = submitted_data
        recipe.is_submitted = True
        
        # Get the associated task and bron_id (relationships already loaded)
        task = recipe.task
        bron_id = recipe.message.bron_id if recipe.message else (task.bron_id if task else None)
        
        if not bron_id:
            raise ValueError("Could not determine Bron ID for recipe submission")
        
        # Get all previously submitted data from this task's UI Recipes
        all_submitted_data = {}
        if task:
            submitted_recipes = await self.db.execute(
                select(UIRecipe).where(
                    UIRecipe.task_id == task.id,
                    UIRecipe.is_submitted == True
                )
            )
            for prev_recipe in submitted_recipes.scalars().all():
                if prev_recipe.submitted_data:
                    import json
                    try:
                        prev_data = json.loads(prev_recipe.submitted_data) if isinstance(prev_recipe.submitted_data, str) else prev_recipe.submitted_data
                        all_submitted_data.update(prev_data)
                    except (json.JSONDecodeError, TypeError):
                        pass
        
        # Add current submission
        all_submitted_data.update(submitted_data)
        
        # Get conversation history
        history = await self._get_conversation_history(bron_id, limit=10)
        
        # Build comprehensive message with all collected data
        message_content = f"""User has provided the following information for their task:

{all_submitted_data}

Based on this information, either:
1. If you have enough info to proceed, provide a helpful response or plan (do NOT ask for more info)
2. If critical information is still missing that prevents you from helping, use the request_user_input tool to ask for ONLY the missing essentials

Do NOT ask for information that has already been provided above."""
        
        agent_response = await claude_service.process_message(
            user_message=message_content,
            bron_id=bron_id,
            task_context=self._build_task_context(task) if task else None,
            conversation_history=history,
        )
        
        # Get Bron for response handling
        bron = await self._get_bron(bron_id)
        
        # Handle the response
        response = await self._handle_agent_response(
            bron=bron,
            task=task,
            response=agent_response,
        )
        
        return response

    # ========================================================================
    # Private Methods
    # ========================================================================

    async def _get_bron(self, bron_id: UUID) -> Optional[BronInstance]:
        """Get a Bron by ID."""
        result = await self.db.execute(
            select(BronInstance).where(BronInstance.id == bron_id)
        )
        return result.scalar_one_or_none()

    async def _get_current_task(self, bron: BronInstance) -> Optional[Task]:
        """Get the current task for a Bron."""
        if not bron.current_task_id:
            return None
        
        result = await self.db.execute(
            select(Task).where(Task.id == bron.current_task_id)
        )
        return result.scalar_one_or_none()

    async def _get_conversation_history(
        self,
        bron_id: UUID,
        limit: int = 10,
    ) -> list[dict]:
        """Get recent conversation history."""
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.bron_id == bron_id)
            .order_by(ChatMessage.created_at.desc())
            .limit(limit)
        )
        messages = result.scalars().all()
        
        history = []
        for msg in reversed(messages):
            # Handle both enum and string role values
            role = msg.role.value if hasattr(msg.role, 'value') else str(msg.role)
            history.append({"role": role, "content": msg.content})
        
        return history

    def _build_task_context(self, task: Task) -> dict:
        """Build task context dictionary."""
        # Handle both enum and string values for state/category
        state_val = task.state.value if hasattr(task.state, 'value') else task.state
        category_val = task.category.value if hasattr(task.category, 'value') else task.category
        return {
            "id": str(task.id),
            "title": task.title,
            "description": task.description,
            "state": state_val,
            "category": category_val,
            "progress": task.progress,
            "next_action": task.next_action,
            "waiting_on": task.waiting_on,
        }

    def _detect_category(self, text: str) -> str:
        """Simple category detection based on keywords."""
        text_lower = text.lower()
        if any(w in text_lower for w in ["email", "calendar", "meeting", "schedule"]):
            return "admin"
        if any(w in text_lower for w in ["write", "design", "create", "draw"]):
            return "creative"
        if any(w in text_lower for w in ["homework", "study", "class", "exam"]):
            return "school"
        if any(w in text_lower for w in ["work", "project", "deadline", "report"]):
            return "work"
        return "personal"

    def _generate_task_title(self, message: str) -> str:
        """Generate a 1-3 word title from the user's message."""
        text = message.strip().lower()
        
        # Remove common filler phrases
        filler_phrases = [
            "can you ", "could you ", "please ", "i need to ", "i want to ",
            "help me ", "i'd like to ", "i would like to ", "let's ",
            "i need ", "i want ", "help ", "can ", "could ",
        ]
        for phrase in filler_phrases:
            if text.startswith(phrase):
                text = text[len(phrase):]
        
        # Remove trailing punctuation
        text = text.rstrip('?!.,')
        
        # Extract key words (skip common words)
        skip_words = {
            'a', 'an', 'the', 'my', 'your', 'to', 'for', 'with', 'and',
            'or', 'in', 'on', 'at', 'of', 'that', 'this', 'it', 'is',
            'me', 'some', 'about', 'up', 'out', 'so', 'what', 'how',
        }
        
        words = text.split()
        key_words = [w for w in words if w not in skip_words][:3]
        
        # If we filtered too much, use first 3 words
        if not key_words:
            key_words = words[:3]
        
        # Capitalize each word
        title = ' '.join(w.capitalize() for w in key_words)
        
        return title or "New Task"

    async def _handle_agent_response(
        self,
        bron: BronInstance,
        task: Optional[Task],
        response: AgentResponse,
    ) -> ChatMessage:
        """Handle the agent's response and create appropriate database entries."""
        # Update task state if needed
        if response.task_update and task:
            if response.task_update.new_state:
                task.state = TaskState(response.task_update.new_state)
            if response.task_update.progress is not None:
                task.progress = response.task_update.progress
            if response.task_update.next_action:
                task.next_action = response.task_update.next_action
            if response.task_update.waiting_on:
                task.waiting_on = response.task_update.waiting_on
        
        # Update Bron status based on intent
        if response.intent == AgentIntent.COMPLETE:
            bron.status = BronStatus.IDLE
            if task:
                task.state = TaskState.DONE
                task.progress = 1.0
        elif response.intent == AgentIntent.REQUEST_INFO:
            bron.status = BronStatus.NEEDS_INFO
            if task:
                task.state = TaskState.NEEDS_INFO
                # If UI Recipe has a title, use it for waiting_on
                if response.ui_recipe and response.ui_recipe.title:
                    task.waiting_on = response.ui_recipe.title
        elif response.intent == AgentIntent.EXECUTE:
            bron.status = BronStatus.READY
            if task:
                task.state = TaskState.READY
        elif response.intent == AgentIntent.ERROR:
            if task:
                task.state = TaskState.FAILED
        
        # Create assistant message
        task_state_str = None
        if task:
            task_state_str = task.state.value if hasattr(task.state, 'value') else task.state
        assistant_message = ChatMessage(
            bron_id=bron.id,
            role=MessageRole.ASSISTANT,
            content=response.message,
            task_state_update=task_state_str,
        )
        self.db.add(assistant_message)
        await self.db.flush()
        
        # Create UI Recipe if needed
        if response.ui_recipe:
            ui_recipe = await self._create_ui_recipe(
                task_id=task.id if task else None,
                spec=response.ui_recipe,
                message_id=assistant_message.id,
            )
        
        await self.db.refresh(assistant_message)
        return assistant_message

    async def _create_ui_recipe(
        self,
        task_id: Optional[UUID],
        spec: UIRecipeSpec,
        message_id: Optional[UUID] = None,
    ) -> UIRecipe:
        """Create a UI Recipe from a specification."""
        # Create style if preset specified
        style = None
        if spec.style_preset:
            style = UIStyle(
                preset=UIStylePreset(spec.style_preset),
            )
            self.db.add(style)
            await self.db.flush()
        
        # Create the UI Recipe
        ui_recipe = UIRecipe(
            component_type=UIComponentType(spec.component_type),
            title=spec.title,
            description=spec.description,
            schema=spec.schema_fields,
            required_fields=spec.required_fields,
            task_id=task_id,
            message_id=message_id,
            style_id=style.id if style else None,
        )
        self.db.add(ui_recipe)
        await self.db.flush()
        
        return ui_recipe

    async def _create_error_response(
        self,
        bron_id: UUID,
        error_message: str,
    ) -> ChatMessage:
        """Create an error response message."""
        message = ChatMessage(
            bron_id=bron_id,
            role=MessageRole.ASSISTANT,
            content=f"I encountered an issue: {error_message}. Please try again.",
        )
        self.db.add(message)
        await self.db.flush()
        await self.db.refresh(message)
        return message

