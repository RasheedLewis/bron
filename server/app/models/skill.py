"""
Skill model - reusable workflows.
"""

from typing import Optional
from uuid import UUID

from sqlalchemy import ForeignKey, Integer, String, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import JSON

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin


class Skill(Base, UUIDMixin, TimestampMixin):
    """
    Skill model representing a saved, reusable workflow.
    
    Skills can be:
    - Created from completed task plans
    - Edited by users
    - Applied to new tasks
    - Versioned for history
    """
    
    __tablename__ = "skills"
    
    # Core fields
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Versioning
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    
    # Relationships
    steps: Mapped[list["SkillStep"]] = relationship(
        "SkillStep",
        back_populates="skill",
        cascade="all, delete-orphan",
        order_by="SkillStep.order",
    )
    
    parameters: Mapped[list["SkillParameter"]] = relationship(
        "SkillParameter",
        back_populates="skill",
        cascade="all, delete-orphan",
    )
    
    def __repr__(self) -> str:
        return f"<Skill {self.id}: {self.name} v{self.version}>"


class SkillStep(Base, UUIDMixin):
    """A step within a Skill workflow."""
    
    __tablename__ = "skill_steps"
    
    # Ordering
    order: Mapped[int] = mapped_column(Integer, nullable=False)
    
    # Content
    instruction: Mapped[str] = mapped_column(Text, nullable=False)
    
    # Input requirements
    requires_user_input: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    input_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
    # Relationship
    skill_id: Mapped[UUID] = mapped_column(ForeignKey("skills.id"), nullable=False)
    skill: Mapped["Skill"] = relationship("Skill", back_populates="steps")
    
    def __repr__(self) -> str:
        return f"<SkillStep {self.order}: {self.instruction[:30]}...>"


class SkillParameter(Base, UUIDMixin):
    """A parameter that can be injected into a Skill."""
    
    __tablename__ = "skill_parameters"
    
    # Definition
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    param_type: Mapped[str] = mapped_column(String(20), nullable=False)  # text, number, date, etc.
    required: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    default_value: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    # Relationship
    skill_id: Mapped[UUID] = mapped_column(ForeignKey("skills.id"), nullable=False)
    skill: Mapped["Skill"] = relationship("Skill", back_populates="parameters")
    
    def __repr__(self) -> str:
        return f"<SkillParameter {self.name}: {self.param_type}>"

