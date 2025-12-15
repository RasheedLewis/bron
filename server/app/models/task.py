"""
Task model and related enums.
"""

from enum import Enum
from typing import TYPE_CHECKING, Optional
from uuid import UUID

from sqlalchemy import Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.bron import BronInstance


class TaskState(str, Enum):
    """Task state enumeration matching PRD specification."""
    
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


class TaskStepStatus(str, Enum):
    """Status of a task step."""
    
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    SKIPPED = "skipped"


class TaskStep(Base, UUIDMixin):
    """
    A single step in a task's execution plan.
    
    Steps are the to-do list that Bron works through.
    """
    
    __tablename__ = "task_steps"
    
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[TaskStepStatus] = mapped_column(
        String(20),
        default=TaskStepStatus.PENDING,
        nullable=False,
    )
    order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    
    # Relationship to Task
    task_id: Mapped[UUID] = mapped_column(ForeignKey("tasks.id"), nullable=False)
    task: Mapped["Task"] = relationship("Task", back_populates="steps")
    
    def __repr__(self) -> str:
        return f"<TaskStep {self.order}: {self.title} [{self.status.value}]>"


class Task(Base, UUIDMixin, TimestampMixin):
    """
    Task model representing work being done by a Bron.
    
    Tasks progress through states (not complexity levels) and may
    generate UI Recipes when they need structured information.
    """
    
    __tablename__ = "tasks"
    
    # Core fields
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # State management
    state: Mapped[TaskState] = mapped_column(
        String(20),
        default=TaskState.DRAFT,
        nullable=False,
    )
    category: Mapped[TaskCategory] = mapped_column(
        String(20),
        default=TaskCategory.OTHER,
        nullable=False,
    )
    
    # Progress tracking
    progress: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    next_action: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    waiting_on: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    # Relationships
    bron_id: Mapped[UUID] = mapped_column(ForeignKey("brons.id"), nullable=False)
    bron: Mapped["BronInstance"] = relationship(
        "BronInstance",
        back_populates="tasks",
        foreign_keys=[bron_id],
    )
    
    # Task steps (the execution plan)
    steps: Mapped[list["TaskStep"]] = relationship(
        "TaskStep",
        back_populates="task",
        cascade="all, delete-orphan",
        order_by="TaskStep.order",
    )
    
    # UI Recipes generated for this task
    ui_recipes: Mapped[list["UIRecipe"]] = relationship(
        "UIRecipe",
        back_populates="task",
        cascade="all, delete-orphan",
    )
    
    @property
    def current_step(self) -> Optional["TaskStep"]:
        """Get the current step being worked on."""
        for step in self.steps:
            if step.status == TaskStepStatus.IN_PROGRESS:
                return step
        for step in self.steps:
            if step.status == TaskStepStatus.PENDING:
                return step
        return None
    
    @property
    def step_progress(self) -> float:
        """Calculate progress based on completed steps."""
        if not self.steps:
            return self.progress
        completed = sum(1 for s in self.steps if s.status == TaskStepStatus.COMPLETED)
        return completed / len(self.steps)
    
    def __repr__(self) -> str:
        return f"<Task {self.id}: {self.title} [{self.state.value}]>"


# Import here to avoid circular imports
from app.models.ui_recipe import UIRecipe  # noqa: E402

