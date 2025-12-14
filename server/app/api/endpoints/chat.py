"""
Chat endpoints for Bron interaction.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models import ChatMessage, MessageRole, BronInstance, UIRecipe
from app.schemas import MessageCreate, MessageResponse, ChatHistoryResponse, UIRecipeSubmission
from app.services.orchestrator import TaskOrchestrator

router = APIRouter()


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
    
    # Get messages
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.bron_id == bron_id)
        .order_by(ChatMessage.created_at.asc())
        .offset(offset)
        .limit(limit)
    )
    messages = result.scalars().all()
    
    return ChatHistoryResponse(
        messages=[MessageResponse.model_validate(m) for m in messages],
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
    
    try:
        # Check if this is a new task or continuing existing one
        if bron.current_task_id:
            # Continue existing task
            response = await orchestrator.process_user_message(
                bron_id=request.bron_id,
                message_content=request.content,
            )
        else:
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
    
    return MessageResponse.model_validate(response)


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
    
    return MessageResponse.model_validate(response)


@router.post("/ui-recipe/submit", response_model=MessageResponse)
async def submit_ui_recipe(
    request: UIRecipeSubmission,
    db: AsyncSession = Depends(get_db),
):
    """
    Submit data from a UI Recipe form.
    
    Processes the submitted data and continues the task workflow.
    """
    # Find the UI Recipe
    result = await db.execute(
        select(UIRecipe).where(UIRecipe.id == request.recipe_id)
    )
    recipe = result.scalar_one_or_none()
    
    if not recipe:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="UI Recipe not found",
        )
    
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
        
        # Get bron_id from recipe
        bron_id = recipe.message.bron_id if recipe.message else recipe.task.bron_id
        
        response = ChatMessage(
            bron_id=bron_id,
            role=MessageRole.ASSISTANT,
            content="I received your information but encountered an issue processing it. Let me try again.",
        )
        db.add(response)
        await db.flush()
        await db.refresh(response)
    
    return MessageResponse.model_validate(response)


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
