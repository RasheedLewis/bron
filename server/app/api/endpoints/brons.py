"""
Bron (Agent) endpoints.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models import BronInstance, BronStatus
from app.schemas import BronCreate, BronUpdate, BronResponse, BronListResponse

router = APIRouter()


@router.get("", response_model=BronListResponse)
async def list_brons(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
):
    """List all active Brons."""
    # Get total count
    count_result = await db.execute(select(func.count(BronInstance.id)))
    total = count_result.scalar() or 0
    
    # Get brons
    result = await db.execute(
        select(BronInstance)
        .order_by(BronInstance.updated_at.desc())
        .offset(skip)
        .limit(limit)
    )
    brons = result.scalars().all()
    
    return BronListResponse(
        brons=[BronResponse.model_validate(b) for b in brons],
        total=total,
    )


@router.post("", response_model=BronResponse, status_code=status.HTTP_201_CREATED)
async def create_bron(
    request: BronCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a new Bron agent."""
    bron = BronInstance(
        name=request.name or "New Bron",
        status=BronStatus.IDLE,
    )
    db.add(bron)
    await db.flush()
    await db.refresh(bron)
    
    return BronResponse.model_validate(bron)


@router.get("/{bron_id}", response_model=BronResponse)
async def get_bron(
    bron_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific Bron by ID."""
    result = await db.execute(
        select(BronInstance).where(BronInstance.id == bron_id)
    )
    bron = result.scalar_one_or_none()
    
    if not bron:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bron not found",
        )
    
    return BronResponse.model_validate(bron)


@router.patch("/{bron_id}", response_model=BronResponse)
async def update_bron(
    bron_id: UUID,
    request: BronUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Update a Bron."""
    result = await db.execute(
        select(BronInstance).where(BronInstance.id == bron_id)
    )
    bron = result.scalar_one_or_none()
    
    if not bron:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bron not found",
        )
    
    # Update fields
    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(bron, field, value)
    
    await db.flush()
    await db.refresh(bron)
    
    return BronResponse.model_validate(bron)


@router.delete("/{bron_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_bron(
    bron_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Delete a Bron."""
    result = await db.execute(
        select(BronInstance).where(BronInstance.id == bron_id)
    )
    bron = result.scalar_one_or_none()
    
    if not bron:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bron not found",
        )
    
    await db.delete(bron)
