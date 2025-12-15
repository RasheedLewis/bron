"""
OAuth endpoints for handling authentication flows.

Supports:
- Google OAuth 2.0
- Apple Sign In
"""

import secrets
import urllib.parse
from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.db.session import get_db
from app.models.credential import Credential, CredentialType, ServiceProvider

router = APIRouter()

# In-memory state storage (in production, use Redis or database)
oauth_states: dict[str, dict] = {}


class OAuthStartRequest(BaseModel):
    """Request to start OAuth flow."""
    provider: str  # google, apple
    bron_id: str
    scopes: Optional[list[str]] = None


class OAuthStartResponse(BaseModel):
    """Response with OAuth URL to open."""
    auth_url: str
    state: str


class OAuthTokenRequest(BaseModel):
    """Request to exchange code for token."""
    provider: str
    code: str
    state: str


class OAuthTokenResponse(BaseModel):
    """Response with token status."""
    success: bool
    provider: str
    message: str


# =============================================================================
# Google OAuth
# =============================================================================

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"

DEFAULT_GOOGLE_SCOPES = [
    "openid",
    "email",
    "profile",
]

GMAIL_SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
]

CALENDAR_SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events",
]


@router.post("/start", response_model=OAuthStartResponse)
async def start_oauth(request: OAuthStartRequest):
    """
    Start an OAuth flow. Returns a URL to open in a browser.
    
    The URL will redirect back to the app with an authorization code.
    """
    if request.provider.lower() == "google":
        return await _start_google_oauth(request)
    elif request.provider.lower() == "apple":
        return await _start_apple_oauth(request)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported OAuth provider: {request.provider}"
        )


async def _start_google_oauth(request: OAuthStartRequest) -> OAuthStartResponse:
    """Start Google OAuth flow."""
    if not settings.google_client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google OAuth not configured. Set GOOGLE_CLIENT_ID in environment."
        )
    
    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)
    
    # Store state with metadata
    oauth_states[state] = {
        "provider": "google",
        "bron_id": request.bron_id,
        "created_at": datetime.utcnow(),
        "scopes": request.scopes or DEFAULT_GOOGLE_SCOPES,
    }
    
    # Build scopes
    scopes = request.scopes or DEFAULT_GOOGLE_SCOPES
    
    # Build authorization URL
    params = {
        "client_id": settings.google_client_id,
        "redirect_uri": settings.google_redirect_uri,
        "response_type": "code",
        "scope": " ".join(scopes),
        "state": state,
        "access_type": "offline",  # Get refresh token
        "prompt": "consent",  # Always show consent screen for refresh token
    }
    
    auth_url = f"{GOOGLE_AUTH_URL}?{urllib.parse.urlencode(params)}"
    
    return OAuthStartResponse(auth_url=auth_url, state=state)


async def _start_apple_oauth(request: OAuthStartRequest) -> OAuthStartResponse:
    """Start Apple Sign In flow."""
    # Apple Sign In implementation would go here
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Apple Sign In not yet implemented"
    )


@router.post("/callback", response_model=OAuthTokenResponse)
async def oauth_callback(
    request: OAuthTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Handle OAuth callback with authorization code.
    
    Exchange the code for tokens and store them.
    """
    # Validate state
    state_data = oauth_states.pop(request.state, None)
    if not state_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OAuth state"
        )
    
    # Check state hasn't expired (15 minutes)
    if datetime.utcnow() - state_data["created_at"] > timedelta(minutes=15):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OAuth state expired"
        )
    
    if request.provider.lower() == "google":
        return await _handle_google_callback(request, state_data, db)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported OAuth provider: {request.provider}"
        )


async def _handle_google_callback(
    request: OAuthTokenRequest,
    state_data: dict,
    db: AsyncSession,
) -> OAuthTokenResponse:
    """Exchange Google authorization code for tokens."""
    import httpx
    
    # Exchange code for tokens
    token_data = {
        "client_id": settings.google_client_id,
        "client_secret": settings.google_client_secret,
        "code": request.code,
        "grant_type": "authorization_code",
        "redirect_uri": settings.google_redirect_uri,
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(GOOGLE_TOKEN_URL, data=token_data)
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Failed to exchange code: {response.text}"
            )
        
        tokens = response.json()
    
    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token")
    expires_in = tokens.get("expires_in", 3600)
    
    # Get user info
    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {access_token}"}
        response = await client.get(GOOGLE_USERINFO_URL, headers=headers)
        user_info = response.json() if response.status_code == 200 else {}
    
    # Store credential
    bron_id = UUID(state_data["bron_id"])
    
    # Check if credential already exists
    existing = await db.execute(
        select(Credential).where(
            Credential.bron_id == bron_id,
            Credential.provider == ServiceProvider.GOOGLE,
        )
    )
    credential = existing.scalar_one_or_none()
    
    if credential:
        # Update existing
        credential.token = access_token
        if refresh_token:
            credential.refresh_token = refresh_token
        credential.expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        credential.extra_data = {
            "scopes": state_data.get("scopes", []),
            "user_email": user_info.get("email"),
            "user_name": user_info.get("name"),
        }
    else:
        # Create new
        credential = Credential(
            credential_type=CredentialType.OAUTH,
            provider=ServiceProvider.GOOGLE,
            token=access_token,
            refresh_token=refresh_token,
            expires_at=datetime.utcnow() + timedelta(seconds=expires_in),
            extra_data={
                "scopes": state_data.get("scopes", []),
                "user_email": user_info.get("email"),
                "user_name": user_info.get("name"),
            },
            bron_id=bron_id,
        )
        db.add(credential)
    
    await db.commit()
    
    user_email = user_info.get("email", "your account")
    return OAuthTokenResponse(
        success=True,
        provider="google",
        message=f"Successfully connected to {user_email}",
    )


@router.get("/check/{provider}")
async def check_oauth_status(
    provider: str,
    bron_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """Check if a valid OAuth token exists for a provider."""
    try:
        provider_enum = ServiceProvider(provider.lower())
    except ValueError:
        return {"authenticated": False, "reason": "Unknown provider"}
    
    result = await db.execute(
        select(Credential).where(
            Credential.bron_id == UUID(bron_id),
            Credential.provider == provider_enum,
            Credential.credential_type == CredentialType.OAUTH,
        )
    )
    credential = result.scalar_one_or_none()
    
    if not credential:
        return {"authenticated": False, "reason": "No credential found"}
    
    # Check if expired
    if credential.expires_at and credential.expires_at < datetime.utcnow():
        # Try to refresh if we have a refresh token
        if credential.refresh_token:
            return {"authenticated": False, "reason": "Token expired, needs refresh"}
        return {"authenticated": False, "reason": "Token expired"}
    
    return {
        "authenticated": True,
        "user_email": credential.extra_data.get("user_email") if credential.extra_data else None,
    }

