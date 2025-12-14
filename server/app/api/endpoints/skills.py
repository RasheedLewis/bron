"""
Skill endpoints.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models import Skill, SkillStep, SkillParameter
from app.schemas import SkillCreate, SkillUpdate, SkillResponse, SkillListResponse

router = APIRouter()


@router.get("", response_model=SkillListResponse)
async def list_skills(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
):
    """List all skills."""
    # Get total count
    count_result = await db.execute(select(func.count(Skill.id)))
    total = count_result.scalar() or 0
    
    # Get skills
    result = await db.execute(
        select(Skill)
        .order_by(Skill.name.asc())
        .offset(skip)
        .limit(limit)
    )
    skills = result.scalars().all()
    
    return SkillListResponse(
        skills=[SkillResponse.model_validate(s) for s in skills],
        total=total,
    )


@router.post("", response_model=SkillResponse, status_code=status.HTTP_201_CREATED)
async def create_skill(
    request: SkillCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a new skill."""
    skill = Skill(
        name=request.name,
        description=request.description,
        version=1,
    )
    db.add(skill)
    await db.flush()
    
    # Create steps
    for step_data in request.steps:
        step = SkillStep(
            skill_id=skill.id,
            order=step_data.order,
            instruction=step_data.instruction,
            requires_user_input=step_data.requires_user_input,
            input_type=step_data.input_type.value if step_data.input_type else None,
        )
        db.add(step)
    
    # Create parameters
    for param_data in request.parameters:
        param = SkillParameter(
            skill_id=skill.id,
            name=param_data.name,
            param_type=param_data.param_type.value,
            required=param_data.required,
            default_value=param_data.default_value,
        )
        db.add(param)
    
    await db.flush()
    await db.refresh(skill)
    
    return SkillResponse.model_validate(skill)


@router.get("/{skill_id}", response_model=SkillResponse)
async def get_skill(
    skill_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific skill by ID."""
    result = await db.execute(
        select(Skill).where(Skill.id == skill_id)
    )
    skill = result.scalar_one_or_none()
    
    if not skill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Skill not found",
        )
    
    return SkillResponse.model_validate(skill)


@router.patch("/{skill_id}", response_model=SkillResponse)
async def update_skill(
    skill_id: UUID,
    request: SkillUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Update a skill."""
    result = await db.execute(
        select(Skill).where(Skill.id == skill_id)
    )
    skill = result.scalar_one_or_none()
    
    if not skill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Skill not found",
        )
    
    # Update basic fields
    if request.name is not None:
        skill.name = request.name
    if request.description is not None:
        skill.description = request.description
    
    # Update steps if provided
    if request.steps is not None:
        # Delete existing steps
        for step in skill.steps:
            await db.delete(step)
        
        # Create new steps
        for step_data in request.steps:
            step = SkillStep(
                skill_id=skill.id,
                order=step_data.order,
                instruction=step_data.instruction,
                requires_user_input=step_data.requires_user_input,
                input_type=step_data.input_type.value if step_data.input_type else None,
            )
            db.add(step)
    
    # Update parameters if provided
    if request.parameters is not None:
        # Delete existing parameters
        for param in skill.parameters:
            await db.delete(param)
        
        # Create new parameters
        for param_data in request.parameters:
            param = SkillParameter(
                skill_id=skill.id,
                name=param_data.name,
                param_type=param_data.param_type.value,
                required=param_data.required,
                default_value=param_data.default_value,
            )
            db.add(param)
    
    # Increment version
    skill.version += 1
    
    await db.flush()
    await db.refresh(skill)
    
    return SkillResponse.model_validate(skill)


@router.delete("/{skill_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_skill(
    skill_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Delete a skill."""
    result = await db.execute(
        select(Skill).where(Skill.id == skill_id)
    )
    skill = result.scalar_one_or_none()
    
    if not skill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Skill not found",
        )
    
    await db.delete(skill)

