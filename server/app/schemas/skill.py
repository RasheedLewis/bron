"""
Pydantic schemas for Skill.
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.ui_recipe import UIComponentType, FieldType


class SkillStepCreate(BaseModel):
    """Request model for creating a skill step."""
    
    order: int
    instruction: str
    requires_user_input: bool = False
    input_type: Optional[UIComponentType] = None


class SkillStepResponse(BaseModel):
    """Response model for a skill step."""
    
    id: UUID
    order: int
    instruction: str
    requires_user_input: bool
    input_type: Optional[UIComponentType]

    model_config = {"from_attributes": True}


class SkillParameterCreate(BaseModel):
    """Request model for creating a skill parameter."""
    
    name: str = Field(..., max_length=50)
    param_type: FieldType
    required: bool = True
    default_value: Optional[str] = Field(None, max_length=255)


class SkillParameterResponse(BaseModel):
    """Response model for a skill parameter."""
    
    id: UUID
    name: str
    param_type: FieldType
    required: bool
    default_value: Optional[str]

    model_config = {"from_attributes": True}


class SkillCreate(BaseModel):
    """Request model for creating a skill."""
    
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    steps: list[SkillStepCreate] = []
    parameters: list[SkillParameterCreate] = []


class SkillUpdate(BaseModel):
    """Request model for updating a skill."""
    
    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    steps: Optional[list[SkillStepCreate]] = None
    parameters: Optional[list[SkillParameterCreate]] = None


class SkillResponse(BaseModel):
    """Response model for a skill."""
    
    id: UUID
    name: str
    description: Optional[str]
    version: int
    steps: list[SkillStepResponse]
    parameters: list[SkillParameterResponse]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class SkillListResponse(BaseModel):
    """Response model for listing skills."""
    
    skills: list[SkillResponse]
    total: int

