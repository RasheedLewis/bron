"""
Bron (Agent) endpoints.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from uuid import UUID, uuid4
from datetime import datetime
from typing import Optional

router = APIRouter()


class BronCreate(BaseModel):
    """Request model for creating a new Bron."""
    name: Optional[str] = None


class BronResponse(BaseModel):
    """Response model for a Bron."""
    id: UUID
    name: str
    status: str
    current_task_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime


class BronListResponse(BaseModel):
    """Response model for listing Brons."""
    brons: list[BronResponse]
    total: int


@router.get("", response_model=BronListResponse)
async def list_brons():
    """List all active Brons."""
    # TODO: Implement with database
    return BronListResponse(brons=[], total=0)


@router.post("", response_model=BronResponse)
async def create_bron(request: BronCreate):
    """Create a new Bron agent."""
    # TODO: Implement with database
    now = datetime.utcnow()
    return BronResponse(
        id=uuid4(),
        name=request.name or "New Bron",
        status="idle",
        current_task_id=None,
        created_at=now,
        updated_at=now,
    )


@router.get("/{bron_id}", response_model=BronResponse)
async def get_bron(bron_id: UUID):
    """Get a specific Bron by ID."""
    # TODO: Implement with database
    raise HTTPException(status_code=404, detail="Bron not found")


@router.delete("/{bron_id}")
async def delete_bron(bron_id: UUID):
    """Delete a Bron."""
    # TODO: Implement with database
    raise HTTPException(status_code=404, detail="Bron not found")

