"""
Chat endpoints for Bron interaction.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models import ChatMessage, MessageRole, BronInstance, UIRecipe
from app.schemas import MessageCreate, MessageResponse, ChatHistoryResponse, UIRecipeSubmission
from app.schemas.ui_recipe import UIRecipeResponse
from app.services.orchestrator import TaskOrchestrator

router = APIRouter()


async def message_to_response(db: AsyncSession, message: ChatMessage) -> MessageResponse:
    """Convert a ChatMessage to MessageResponse, properly loading relationships."""
    # Eagerly load the message with ui_recipe
    result = await db.execute(
        select(ChatMessage)
        .options(selectinload(ChatMessage.ui_recipe))
        .where(ChatMessage.id == message.id)
    )
    loaded_message = result.scalar_one()
    
    # Build response dict
    response_data = {
        "id": loaded_message.id,
        "bron_id": loaded_message.bron_id,
        "role": loaded_message.role,
        "content": loaded_message.content,
        "task_state_update": loaded_message.task_state_update,
        "created_at": loaded_message.created_at,
        "ui_recipe": None,
    }
    
    # Add UI Recipe if present
    if loaded_message.ui_recipe:
        recipe = loaded_message.ui_recipe
        response_data["ui_recipe"] = {
            "id": recipe.id,
            "component_type": recipe.component_type,
            "title": recipe.title,
            "description": recipe.description,
            "schema": recipe.schema,
            "required_fields": recipe.required_fields,
            "is_submitted": recipe.is_submitted,
            "submitted_data": recipe.submitted_data,
            "created_at": recipe.created_at,
            "updated_at": recipe.updated_at,
        }
    
    return MessageResponse(**response_data)


@router.get("/{bron_id}/history", response_model=ChatHistoryResponse)
async def get_chat_history(
    bron_id: UUID,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    """Get chat history for a Bron."""
    # Verify Bron exists
    bron_result = await db.execute(
        select(BronInstance).where(BronInstance.id == bron_id)
    )
    bron = bron_result.scalar_one_or_none()
    
    if not bron:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bron not found",
        )
    
    # Get total count
    count_result = await db.execute(
        select(func.count(ChatMessage.id)).where(ChatMessage.bron_id == bron_id)
    )
    total = count_result.scalar() or 0
    
    # Get messages with eager loading of ui_recipe
    result = await db.execute(
        select(ChatMessage)
        .options(selectinload(ChatMessage.ui_recipe))
        .where(ChatMessage.bron_id == bron_id)
        .order_by(ChatMessage.created_at.asc())
        .offset(offset)
        .limit(limit)
    )
    messages = result.scalars().all()
    
    # Convert to response models
    message_responses = []
    for m in messages:
        response_data = {
            "id": m.id,
            "bron_id": m.bron_id,
            "role": m.role,
            "content": m.content,
            "task_state_update": m.task_state_update,
            "created_at": m.created_at,
            "ui_recipe": None,
        }
        if m.ui_recipe:
            response_data["ui_recipe"] = {
                "id": m.ui_recipe.id,
                "component_type": m.ui_recipe.component_type,
                "title": m.ui_recipe.title,
                "description": m.ui_recipe.description,
                "schema": m.ui_recipe.schema,
                "required_fields": m.ui_recipe.required_fields,
                "is_submitted": m.ui_recipe.is_submitted,
                "submitted_data": m.ui_recipe.submitted_data,
                "created_at": m.ui_recipe.created_at,
                "updated_at": m.ui_recipe.updated_at,
            }
        message_responses.append(MessageResponse(**response_data))
    
    return ChatHistoryResponse(
        messages=message_responses,
        total=total,
    )


@router.post("/message", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(
    request: MessageCreate,
    db: AsyncSession = Depends(get_db),
):
    """
    Send a message to a Bron and get a response.
    
    This is the main interaction endpoint. It:
    1. Stores the user message
    2. Processes it through Claude
    3. Creates/updates tasks as needed
    4. Returns the assistant's response with optional UI Recipe
    """
    # Verify Bron exists
    bron_result = await db.execute(
        select(BronInstance).where(BronInstance.id == request.bron_id)
    )
    bron = bron_result.scalar_one_or_none()
    
    if not bron:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bron not found",
        )
    
    # Use orchestrator to process the message
    orchestrator = TaskOrchestrator(db)
    
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"Processing message for Bron {bron.id}, current_task_id: {bron.current_task_id}")
    
    try:
        # Check if this is a new task or continuing existing one
        if bron.current_task_id:
            logger.info(f"Continuing existing task: {bron.current_task_id}")
            # Continue existing task
            response = await orchestrator.process_user_message(
                bron_id=request.bron_id,
                message_content=request.content,
            )
        else:
            logger.info("Creating new task from message")
            # Create new task from message
            task, response = await orchestrator.create_task_from_message(
                bron_id=request.bron_id,
                message_content=request.content,
            )
    except Exception as e:
        # Log the error and return a user-friendly message
        import logging
        logging.error(f"Failed to process message: {e}")
        
        # Create a fallback response
        response = ChatMessage(
            bron_id=request.bron_id,
            role=MessageRole.ASSISTANT,
            content=f"I encountered an issue processing your request. Please try again.",
        )
        db.add(response)
        await db.flush()
        await db.refresh(response)
    
    return await message_to_response(db, response)


@router.post("/message/simple", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def send_simple_message(
    request: MessageCreate,
    db: AsyncSession = Depends(get_db),
):
    """
    Send a simple message without task creation.
    
    Useful for quick questions that don't need task tracking.
    Falls back to basic response if Claude is unavailable.
    """
    from app.services.claude import claude_service, AgentIntent
    
    # Verify Bron exists
    bron_result = await db.execute(
        select(BronInstance).where(BronInstance.id == request.bron_id)
    )
    bron = bron_result.scalar_one_or_none()
    
    if not bron:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bron not found",
        )
    
    # Save user message
    user_message = ChatMessage(
        bron_id=request.bron_id,
        role=MessageRole.USER,
        content=request.content,
    )
    db.add(user_message)
    await db.flush()
    
    try:
        # Process with Claude
        agent_response = await claude_service.process_message(
            user_message=request.content,
        )
        response_content = agent_response.message
    except Exception as e:
        # Fallback response
        response_content = f"I received your message. How can I help you with: '{request.content}'?"
    
    # Create response
    response = ChatMessage(
        bron_id=request.bron_id,
        role=MessageRole.ASSISTANT,
        content=response_content,
    )
    db.add(response)
    await db.flush()
    await db.refresh(response)
    
    return await message_to_response(db, response)


@router.post("/ui-recipe/submit", response_model=MessageResponse)
async def submit_ui_recipe(
    request: UIRecipeSubmission,
    db: AsyncSession = Depends(get_db),
):
    """
    Submit data from a UI Recipe form.
    
    Processes the submitted data and continues the task workflow.
    """
    # Find the UI Recipe with eager loading of relationships
    result = await db.execute(
        select(UIRecipe)
        .options(selectinload(UIRecipe.message), selectinload(UIRecipe.task))
        .where(UIRecipe.id == request.recipe_id)
    )
    recipe = result.scalar_one_or_none()
    
    if not recipe:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="UI Recipe not found",
        )
    
    # Get bron_id now while relationships are loaded
    bron_id = recipe.message.bron_id if recipe.message else (recipe.task.bron_id if recipe.task else None)
    
    if recipe.is_submitted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="UI Recipe has already been submitted",
        )
    
    # Use orchestrator to handle submission
    orchestrator = TaskOrchestrator(db)
    
    try:
        response = await orchestrator.handle_ui_recipe_submission(
            recipe_id=request.recipe_id,
            submitted_data=request.data,
        )
    except Exception as e:
        import logging
        logging.error(f"Failed to process UI Recipe submission: {e}")
        
        if not bron_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not determine Bron for this recipe",
            )
        
        response = ChatMessage(
            bron_id=bron_id,
            role=MessageRole.ASSISTANT,
            content="I received your information but encountered an issue processing it. Let me try again.",
        )
        db.add(response)
        await db.flush()
        await db.refresh(response)
    
    return await message_to_response(db, response)


@router.get("/pending-recipes/{bron_id}")
async def get_pending_recipes(
    bron_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """
    Get pending (unsubmitted) UI Recipes for a Bron.
    
    Useful for displaying forms that the user hasn't responded to yet.
    """
    # Get pending recipes through messages
    result = await db.execute(
        select(UIRecipe)
        .join(ChatMessage)
        .where(
            ChatMessage.bron_id == bron_id,
            UIRecipe.is_submitted == False,
        )
        .order_by(UIRecipe.created_at.desc())
    )
    recipes = result.scalars().all()
    
    return {
        "recipes": [
            {
                "id": str(recipe.id),
                "component_type": recipe.component_type.value,
                "title": recipe.title,
                "description": recipe.description,
                "schema": recipe.schema,
                "required_fields": recipe.required_fields,
            }
            for recipe in recipes
        ],
        "total": len(recipes),
    }
