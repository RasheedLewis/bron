"""
Pydantic schemas for Chat.
"""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID

from pydantic import BaseModel

from app.models.chat import MessageRole
from app.schemas.ui_recipe import UIRecipeResponse


class MessageCreate(BaseModel):
    """Request model for sending a message."""
    
    bron_id: UUID
    content: str


class MessageResponse(BaseModel):
    """Response model for a chat message."""
    
    id: UUID
    bron_id: UUID
    role: MessageRole
    content: str
    ui_recipe: Optional[UIRecipeResponse] = None
    task_state_update: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatHistoryResponse(BaseModel):
    """Response model for chat history."""
    
    messages: list[MessageResponse]
    total: int


class UIRecipeSubmission(BaseModel):
    """Request model for submitting UI Recipe data."""
    
    recipe_id: UUID
    data: dict[str, Any]

