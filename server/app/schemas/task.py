"""
Pydantic schemas for Task.
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.task import TaskState, TaskCategory


class TaskCreate(BaseModel):
    """Request model for creating a task."""
    
    title: str = Field(..., max_length=255)
    description: Optional[str] = None
    bron_id: UUID
    category: Optional[TaskCategory] = TaskCategory.OTHER


class TaskUpdate(BaseModel):
    """Request model for updating a task."""
    
    title: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    state: Optional[TaskState] = None
    category: Optional[TaskCategory] = None
    progress: Optional[float] = Field(None, ge=0.0, le=1.0)
    next_action: Optional[str] = Field(None, max_length=255)
    waiting_on: Optional[str] = Field(None, max_length=255)


class TaskResponse(BaseModel):
    """Response model for a task."""
    
    id: UUID
    title: str
    description: Optional[str]
    state: TaskState
    category: TaskCategory
    bron_id: UUID
    progress: float
    next_action: Optional[str]
    waiting_on: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TaskListResponse(BaseModel):
    """Response model for listing tasks."""
    
    tasks: list[TaskResponse]
    total: int

