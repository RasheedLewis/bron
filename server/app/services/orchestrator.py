"""
Task Orchestration Service.
Coordinates between Claude, tasks, and the chat system.
"""

import logging
from typing import Optional
from uuid import UUID

from sqlalchemy import select
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
        
        # Process with Claude
        try:
            agent_response = await claude_service.process_message(
                user_message=message_content,
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
        
        # Analyze the task with Claude
        analysis = await claude_service.analyze_task(message_content)
        
        # Create the task
        task = Task(
            title=message_content[:100],  # Truncate for title
            description=message_content,
            state=TaskState.DRAFT,
            category=TaskCategory(analysis.get("category", "other")),
            bron_id=bron_id,
            progress=0.0,
            next_action=analysis.get("first_action"),
        )
        self.db.add(task)
        
        # Update Bron's current task
        bron.current_task_id = task.id
        bron.status = BronStatus.WORKING
        
        await self.db.flush()
        
        # Generate initial response
        if analysis.get("required_info"):
            # Need information - generate UI Recipe
            ui_recipe_spec = await claude_service.generate_ui_recipe(
                task_context=self._build_task_context(task),
                missing_info=analysis["required_info"],
            )
            
            # Create UI Recipe
            ui_recipe = await self._create_ui_recipe(task.id, ui_recipe_spec)
            
            # Update task state
            task.state = TaskState.NEEDS_INFO
            task.waiting_on = ", ".join(analysis["required_info"][:3])
            
            # Create response message with UI Recipe
            response = ChatMessage(
                bron_id=bron_id,
                role=MessageRole.ASSISTANT,
                content=f"I'll help you with that! To get started, I need some information.",
                task_state_update=TaskState.NEEDS_INFO.value,
            )
            self.db.add(response)
            
            # Link UI Recipe to message
            ui_recipe.message_id = response.id
            
            await self.db.flush()
            await self.db.refresh(response)
            
        else:
            # Can start immediately
            task.state = TaskState.PLANNED
            
            steps_text = "\n".join(f"• {step}" for step in analysis.get("steps", []))
            response = ChatMessage(
                bron_id=bron_id,
                role=MessageRole.ASSISTANT,
                content=f"I understand! Here's my plan:\n\n{steps_text}\n\nShall I proceed?",
                task_state_update=TaskState.PLANNED.value,
            )
            self.db.add(response)
            await self.db.flush()
            await self.db.refresh(response)
        
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
        # Get the UI Recipe
        result = await self.db.execute(
            select(UIRecipe).where(UIRecipe.id == recipe_id)
        )
        recipe = result.scalar_one_or_none()
        
        if not recipe:
            raise ValueError(f"UI Recipe not found: {recipe_id}")
        
        # Mark as submitted
        recipe.submitted_data = submitted_data
        recipe.is_submitted = True
        
        # Get the associated task
        task = recipe.task
        bron_id = recipe.message.bron_id if recipe.message else task.bron_id
        
        # Process the submission with Claude
        message_content = f"User submitted: {submitted_data}"
        
        agent_response = await claude_service.process_message(
            user_message=message_content,
            task_context=self._build_task_context(task) if task else None,
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
        
        return [
            {"role": msg.role.value, "content": msg.content}
            for msg in reversed(messages)
        ]

    def _build_task_context(self, task: Task) -> dict:
        """Build task context dictionary."""
        return {
            "id": str(task.id),
            "title": task.title,
            "description": task.description,
            "state": task.state.value,
            "category": task.category.value,
            "progress": task.progress,
            "next_action": task.next_action,
            "waiting_on": task.waiting_on,
        }

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
        elif response.intent == AgentIntent.EXECUTE:
            bron.status = BronStatus.READY
        elif response.intent == AgentIntent.ERROR:
            if task:
                task.state = TaskState.FAILED
        
        # Create assistant message
        assistant_message = ChatMessage(
            bron_id=bron.id,
            role=MessageRole.ASSISTANT,
            content=response.message,
            task_state_update=task.state.value if task else None,
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

