"""
Pydantic schemas for UIRecipe.
"""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.ui_recipe import UIComponentType, FieldType


class FieldValidationSchema(BaseModel):
    """Validation rules for a schema field."""
    
    required: Optional[bool] = None
    min_length: Optional[int] = None
    max_length: Optional[int] = None
    pattern: Optional[str] = None


class SchemaFieldResponse(BaseModel):
    """Schema field definition."""
    
    type: FieldType
    label: Optional[str] = None
    placeholder: Optional[str] = None
    options: Optional[list[str]] = None
    validation: Optional[FieldValidationSchema] = None


class UIRecipeCreate(BaseModel):
    """Request model for creating a UI Recipe."""
    
    component_type: UIComponentType
    schema_def: dict[str, SchemaFieldResponse] = Field(default_factory=dict, alias="schema")
    required_fields: list[str] = []
    title: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    task_id: Optional[UUID] = None


class UIRecipeResponse(BaseModel):
    """Response model for a UI Recipe."""
    
    id: UUID
    component_type: UIComponentType
    schema_def: dict[str, Any] = Field(alias="schema")
    required_fields: list[str]
    title: Optional[str]
    description: Optional[str]
    is_submitted: bool
    submitted_data: Optional[dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True, "populate_by_name": True}

