"""
Task endpoints.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from uuid import UUID, uuid4
from datetime import datetime
from typing import Optional
from enum import Enum

router = APIRouter()


class TaskState(str, Enum):
    """Task state enumeration."""
    DRAFT = "draft"
    NEEDS_INFO = "needs_info"
    PLANNED = "planned"
    READY = "ready"
    EXECUTING = "executing"
    WAITING = "waiting"
    DONE = "done"
    FAILED = "failed"


class TaskCategory(str, Enum):
    """Task category enumeration."""
    ADMIN = "admin"
    CREATIVE = "creative"
    SCHOOL = "school"
    PERSONAL = "personal"
    WORK = "work"
    OTHER = "other"


class TaskCreate(BaseModel):
    """Request model for creating a task."""
    title: str
    description: Optional[str] = None
    bron_id: UUID
    category: Optional[TaskCategory] = TaskCategory.OTHER


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


class TaskListResponse(BaseModel):
    """Response model for listing tasks."""
    tasks: list[TaskResponse]
    total: int


@router.get("", response_model=TaskListResponse)
async def list_tasks(bron_id: Optional[UUID] = None, state: Optional[TaskState] = None):
    """List tasks, optionally filtered by Bron ID or state."""
    # TODO: Implement with database
    return TaskListResponse(tasks=[], total=0)


@router.post("", response_model=TaskResponse)
async def create_task(request: TaskCreate):
    """Create a new task."""
    # TODO: Implement with database
    now = datetime.utcnow()
    return TaskResponse(
        id=uuid4(),
        title=request.title,
        description=request.description,
        state=TaskState.DRAFT,
        category=request.category or TaskCategory.OTHER,
        bron_id=request.bron_id,
        progress=0.0,
        next_action=None,
        waiting_on=None,
        created_at=now,
        updated_at=now,
    )


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(task_id: UUID):
    """Get a specific task by ID."""
    # TODO: Implement with database
    raise HTTPException(status_code=404, detail="Task not found")


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(task_id: UUID):
    """Update a task."""
    # TODO: Implement with database
    raise HTTPException(status_code=404, detail="Task not found")


@router.post("/{task_id}/execute")
async def execute_task(task_id: UUID):
    """Execute a task that is in Ready state."""
    # TODO: Implement execution logic
    raise HTTPException(status_code=404, detail="Task not found")

