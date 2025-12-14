"""
ChatMessage model - conversation history.
"""

from enum import Enum
from typing import TYPE_CHECKING, Optional
from uuid import UUID

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.bron import BronInstance
    from app.models.ui_recipe import UIRecipe


class MessageRole(str, Enum):
    """Message role in conversation."""
    
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class ChatMessage(Base, UUIDMixin, TimestampMixin):
    """
    ChatMessage model for conversation history.
    
    Messages can optionally include:
    - UI Recipes for structured input
    - Task state updates
    """
    
    __tablename__ = "chat_messages"
    
    # Content
    role: Mapped[MessageRole] = mapped_column(String(20), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    
    # Optional task state update notification
    task_state_update: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
    # Relationships
    bron_id: Mapped[UUID] = mapped_column(ForeignKey("brons.id"), nullable=False)
    bron: Mapped["BronInstance"] = relationship("BronInstance", back_populates="messages")
    
    # UI Recipe (one-to-one, optional)
    ui_recipe: Mapped[Optional["UIRecipe"]] = relationship(
        "UIRecipe",
        back_populates="message",
        uselist=False,
    )
    
    def __repr__(self) -> str:
        preview = self.content[:30] + "..." if len(self.content) > 30 else self.content
        return f"<ChatMessage {self.role.value}: {preview}>"

