"""
API Router aggregation.
"""

from fastapi import APIRouter

from app.api.endpoints import brons, tasks, chat, skills, credentials, oauth

router = APIRouter()

router.include_router(brons.router, prefix="/brons", tags=["brons"])
router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
router.include_router(chat.router, prefix="/chat", tags=["chat"])
router.include_router(skills.router, prefix="/skills", tags=["skills"])
router.include_router(credentials.router, prefix="/credentials", tags=["credentials"])
router.include_router(oauth.router, prefix="/oauth", tags=["oauth"])

