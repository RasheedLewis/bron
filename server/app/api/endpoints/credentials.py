"""
Credential management API endpoints.

These endpoints handle:
- OAuth callback handling
- API key storage
- Credential listing and revocation
"""

from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.credential import ServiceProvider
from app.services.api_executor import (
    store_oauth_credential,
    store_api_key_credential,
    revoke_credential,
    list_credentials,
    check_has_credential,
)

router = APIRouter()


# =========================================================================
# Request/Response Models
# =========================================================================

class OAuthCallbackRequest(BaseModel):
    """OAuth callback data from client."""
    bron_id: UUID
    provider: ServiceProvider
    access_token: str
    refresh_token: Optional[str] = None
    expires_in: Optional[int] = None  # seconds
    scopes: Optional[list[str]] = None
    user_email: Optional[str] = None
    user_id: Optional[str] = None


class APIKeyRequest(BaseModel):
    """API key submission."""
    bron_id: UUID
    provider: ServiceProvider
    api_key: str
    provider_name: Optional[str] = None  # Custom name if provider is CUSTOM


class CredentialResponse(BaseModel):
    """Credential info (no secrets)."""
    id: UUID
    provider: str
    provider_name: Optional[str]
    credential_type: str
    is_valid: bool
    scopes: Optional[list[str]]
    last_used_at: Optional[str]
    created_at: str


class CredentialCheckRequest(BaseModel):
    """Check if credential exists."""
    bron_id: UUID
    provider: ServiceProvider


class CredentialCheckResponse(BaseModel):
    """Result of credential check."""
    has_credential: bool
    provider: str


# =========================================================================
# Endpoints
# =========================================================================

@router.post("/oauth/callback", status_code=status.HTTP_201_CREATED)
async def handle_oauth_callback(
    request: OAuthCallbackRequest,
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """
    Handle OAuth callback from client.
    
    The iOS app handles the OAuth flow and sends the tokens here.
    """
    try:
        extra_data = {}
        if request.user_email:
            extra_data["email"] = request.user_email
        if request.user_id:
            extra_data["user_id"] = request.user_id
        
        credential = await store_oauth_credential(
            db=db,
            bron_id=request.bron_id,
            provider=request.provider,
            access_token=request.access_token,
            refresh_token=request.refresh_token,
            expires_in=request.expires_in,
            scopes=request.scopes,
            extra_data=extra_data if extra_data else None,
        )
        
        return {
            "success": True,
            "credential_id": str(credential.id),
            "provider": credential.provider.value,
            "message": f"Connected to {credential.provider.value}",
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to store credential: {str(e)}",
        )


@router.post("/api-key", status_code=status.HTTP_201_CREATED)
async def store_api_key(
    request: APIKeyRequest,
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Store an API key for a service."""
    try:
        credential = await store_api_key_credential(
            db=db,
            bron_id=request.bron_id,
            provider=request.provider,
            api_key=request.api_key,
            provider_name=request.provider_name,
        )
        
        return {
            "success": True,
            "credential_id": str(credential.id),
            "provider": credential.provider.value,
            "message": f"API key stored for {request.provider_name or credential.provider.value}",
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to store API key: {str(e)}",
        )


@router.post("/check")
async def check_credential(
    request: CredentialCheckRequest,
    db: AsyncSession = Depends(get_db),
) -> CredentialCheckResponse:
    """Check if a Bron has credentials for a provider."""
    has_cred = await check_has_credential(
        db=db,
        bron_id=request.bron_id,
        provider=request.provider,
    )
    
    return CredentialCheckResponse(
        has_credential=has_cred,
        provider=request.provider.value,
    )


@router.get("/{bron_id}")
async def get_credentials(
    bron_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> list[dict[str, Any]]:
    """List all credentials for a Bron (without secrets)."""
    return await list_credentials(db=db, bron_id=bron_id)


@router.delete("/{credential_id}")
async def delete_credential(
    credential_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Revoke/delete a credential."""
    success = await revoke_credential(db=db, credential_id=credential_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Credential not found",
        )
    
    return {
        "success": True,
        "message": "Credential revoked",
    }

