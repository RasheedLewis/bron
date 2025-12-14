"""
Task endpoints.
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models import Task, TaskState, TaskCategory, BronInstance
from app.schemas import TaskCreate, TaskUpdate, TaskResponse, TaskListResponse

router = APIRouter()


@router.get("", response_model=TaskListResponse)
async def list_tasks(
    bron_id: Optional[UUID] = None,
    state: Optional[TaskState] = None,
    category: Optional[TaskCategory] = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
):
    """List tasks, optionally filtered by Bron ID, state, or category."""
    # Build query
    query = select(Task)
    count_query = select(func.count(Task.id))
    
    if bron_id:
        query = query.where(Task.bron_id == bron_id)
        count_query = count_query.where(Task.bron_id == bron_id)
    
    if state:
        query = query.where(Task.state == state)
        count_query = count_query.where(Task.state == state)
    
    if category:
        query = query.where(Task.category == category)
        count_query = count_query.where(Task.category == category)
    
    # Get total count
    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0
    
    # Get tasks
    result = await db.execute(
        query
        .order_by(Task.updated_at.desc())
        .offset(skip)
        .limit(limit)
    )
    tasks = result.scalars().all()
    
    return TaskListResponse(
        tasks=[TaskResponse.model_validate(t) for t in tasks],
        total=total,
    )


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    request: TaskCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a new task."""
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
    
    task = Task(
        title=request.title,
        description=request.description,
        state=TaskState.DRAFT,
        category=request.category or TaskCategory.OTHER,
        bron_id=request.bron_id,
        progress=0.0,
    )
    db.add(task)
    await db.flush()
    await db.refresh(task)
    
    return TaskResponse.model_validate(task)


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific task by ID."""
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    return TaskResponse.model_validate(task)


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: UUID,
    request: TaskUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Update a task."""
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    # Update fields
    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(task, field, value)
    
    await db.flush()
    await db.refresh(task)
    
    return TaskResponse.model_validate(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Delete a task."""
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    await db.delete(task)


@router.post("/{task_id}/execute", response_model=TaskResponse)
async def execute_task(
    task_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Execute a task that is in Ready state."""
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    
    if task.state != TaskState.READY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Task is not ready for execution. Current state: {task.state.value}",
        )
    
    # Transition to executing
    task.state = TaskState.EXECUTING
    await db.flush()
    await db.refresh(task)
    
    # TODO: Trigger actual execution logic in PR-06
    
    return TaskResponse.model_validate(task)
