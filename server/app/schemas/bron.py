"""
Pydantic schemas for Bron.
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.bron import BronStatus


class BronCreate(BaseModel):
    """Request model for creating a new Bron."""
    
    name: Optional[str] = Field(None, max_length=100)


class BronUpdate(BaseModel):
    """Request model for updating a Bron."""
    
    name: Optional[str] = Field(None, max_length=100)
    status: Optional[BronStatus] = None
    current_task_id: Optional[UUID] = None


class BronResponse(BaseModel):
    """Response model for a Bron."""
    
    id: UUID
    name: str
    status: BronStatus
    current_task_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BronListResponse(BaseModel):
    """Response model for listing Brons."""
    
    brons: list[BronResponse]
    total: int

