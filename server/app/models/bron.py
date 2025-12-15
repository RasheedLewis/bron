"""
BronInstance model - represents an AI agent.
"""

from enum import Enum
from typing import TYPE_CHECKING, Optional
from uuid import UUID

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.task import Task
    from app.models.chat import ChatMessage
    from app.models.credential import Credential


class BronStatus(str, Enum):
    """Bron status states for display in BronListView."""
    
    IDLE = "idle"
    WORKING = "working"
    WAITING = "waiting"
    NEEDS_INFO = "needs_info"
    READY = "ready"
    COMPLETED = "completed"


class BronInstance(Base, UUIDMixin, TimestampMixin):
    """
    BronInstance model representing a Claude-powered agent.
    
    Each Bron:
    - Has one active task at a time
    - Can work in the background
    - Appears in BronListView
    """
    
    __tablename__ = "brons"
    
    # Core fields
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    
    # Status for display
    status: Mapped[BronStatus] = mapped_column(
        String(20),
        default=BronStatus.IDLE,
        nullable=False,
    )
    
    # Current active task (optional)
    current_task_id: Mapped[Optional[UUID]] = mapped_column(
        ForeignKey("tasks.id", use_alter=True),
        nullable=True,
    )
    
    # Relationships
    tasks: Mapped[list["Task"]] = relationship(
        "Task",
        back_populates="bron",
        foreign_keys="Task.bron_id",
        cascade="all, delete-orphan",
    )
    
    messages: Mapped[list["ChatMessage"]] = relationship(
        "ChatMessage",
        back_populates="bron",
        cascade="all, delete-orphan",
    )
    
    credentials: Mapped[list["Credential"]] = relationship(
        "Credential",
        back_populates="bron",
        cascade="all, delete-orphan",
    )
    
    def __repr__(self) -> str:
        return f"<BronInstance {self.id}: {self.name} [{self.status.value}]>"

