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
    """Send a message to a Bron and get a response."""
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
    
    # TODO: Integrate with Claude in PR-02
    # For now, return a placeholder response
    assistant_message = ChatMessage(
        bron_id=request.bron_id,
        role=MessageRole.ASSISTANT,
        content=f"I received your message: '{request.content}'. Claude integration coming in PR-02!",
    )
    db.add(assistant_message)
    await db.flush()
    await db.refresh(assistant_message)
    
    return MessageResponse.model_validate(assistant_message)


@router.post("/ui-recipe/submit", response_model=MessageResponse)
async def submit_ui_recipe(
    request: UIRecipeSubmission,
    db: AsyncSession = Depends(get_db),
):
    """Submit data from a UI Recipe form."""
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
    
    # Mark as submitted
    recipe.submitted_data = request.data
    recipe.is_submitted = True
    
    # Get the associated message's bron_id
    bron_id = recipe.message.bron_id if recipe.message else recipe.task.bron_id
    
    # Create confirmation message
    # TODO: Process with Claude in PR-02
    confirmation = ChatMessage(
        bron_id=bron_id,
        role=MessageRole.ASSISTANT,
        content="Thank you! I've received your input. Processing...",
    )
    db.add(confirmation)
    await db.flush()
    await db.refresh(confirmation)
    
    return MessageResponse.model_validate(confirmation)
