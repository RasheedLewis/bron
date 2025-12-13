"""
API Router aggregation.
"""

from fastapi import APIRouter

from app.api.endpoints import brons, tasks, chat

router = APIRouter()

router.include_router(brons.router, prefix="/brons", tags=["brons"])
router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
router.include_router(chat.router, prefix="/chat", tags=["chat"])

