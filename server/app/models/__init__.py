"""
Database models for Bron server.

All models are imported here for easy access and to ensure
they're registered with SQLAlchemy before migrations run.
"""

from app.models.base import TimestampMixin, UUIDMixin
from app.models.bron import BronInstance, BronStatus
from app.models.task import Task, TaskState, TaskCategory
from app.models.skill import Skill, SkillStep, SkillParameter
from app.models.ui_recipe import UIRecipe, UIComponentType, FieldType, UIStyle, UIStylePreset
from app.models.chat import ChatMessage, MessageRole

__all__ = [
    # Base
    "TimestampMixin",
    "UUIDMixin",
    # Bron
    "BronInstance",
    "BronStatus",
    # Task
    "Task",
    "TaskState",
    "TaskCategory",
    # Skill
    "Skill",
    "SkillStep",
    "SkillParameter",
    # UI Recipe
    "UIRecipe",
    "UIComponentType",
    "FieldType",
    "UIStyle",
    "UIStylePreset",
    # Chat
    "ChatMessage",
    "MessageRole",
]
