"""
API Executor Service - executes API calls on behalf of Brons.

This service:
1. Retrieves stored credentials
2. Handles authentication (OAuth refresh, API keys)
3. Makes HTTP requests to external APIs
4. Parses and returns results
"""

import logging
import httpx
from typing import Any, Optional
from datetime import datetime, timedelta
from uuid import UUID
from dataclasses import dataclass
from enum import Enum

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.credential import Credential, CredentialType, ServiceProvider
from app.services.api_discovery import api_discovery, KNOWN_APIS

logger = logging.getLogger(__name__)


class APIExecutionError(Exception):
    """Base exception for API execution errors."""
    pass


class AuthenticationError(APIExecutionError):
    """Credential missing or invalid."""
    pass


class RateLimitError(APIExecutionError):
    """API rate limit exceeded."""
    pass


class APIResponseError(APIExecutionError):
    """API returned an error."""
    def __init__(self, message: str, status_code: int, response_body: Any = None):
        super().__init__(message)
        self.status_code = status_code
        self.response_body = response_body


class HTTPMethod(str, Enum):
    GET = "GET"
    POST = "POST"
    PUT = "PUT"
    PATCH = "PATCH"
    DELETE = "DELETE"


@dataclass
class APIRequest:
    """Represents an API request to execute."""
    provider: ServiceProvider
    endpoint: str  # Relative path from base URL
    method: HTTPMethod = HTTPMethod.GET
    params: Optional[dict[str, Any]] = None
    body: Optional[dict[str, Any]] = None
    headers: Optional[dict[str, str]] = None


@dataclass
class APIResponse:
    """Response from an API call."""
    success: bool
    status_code: int
    data: Any
    error_message: Optional[str] = None
    rate_limit_remaining: Optional[int] = None
    

class APIExecutor:
    """
    Executes API calls using stored credentials.
    
    Usage:
        executor = APIExecutor(db_session)
        response = await executor.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.GMAIL,
                endpoint="/users/me/messages",
                method=HTTPMethod.GET,
                params={"maxResults": 10}
            )
        )
    """
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self._client: Optional[httpx.AsyncClient] = None
    
    async def __aenter__(self):
        self._client = httpx.AsyncClient(timeout=30.0)
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self._client:
            await self._client.aclose()
    
    async def execute(
        self,
        bron_id: UUID,
        request: APIRequest,
    ) -> APIResponse:
        """
        Execute an API request using stored credentials.
        
        Args:
            bron_id: The Bron making the request
            request: The API request to execute
            
        Returns:
            APIResponse with the result
            
        Raises:
            AuthenticationError: If no valid credentials found
            APIResponseError: If API returns an error
        """
        # Get credentials for this provider
        credential = await self._get_credential(bron_id, request.provider)
        if not credential:
            raise AuthenticationError(
                f"No credentials found for {request.provider.value}. "
                "User needs to authenticate first."
            )
        
        # Check if token needs refresh
        if credential.needs_refresh and credential.refresh_token:
            credential = await self._refresh_token(credential)
        
        # Build the request
        api_info = KNOWN_APIS.get(request.provider.value)
        if not api_info:
            raise APIExecutionError(f"Unknown API provider: {request.provider.value}")
        
        url = f"{api_info.base_url}{request.endpoint}"
        headers = await self._build_headers(credential, request.headers)
        
        # Execute the request
        try:
            if self._client is None:
                self._client = httpx.AsyncClient(timeout=30.0)
            
            response = await self._make_request(
                method=request.method,
                url=url,
                headers=headers,
                params=request.params,
                json=request.body,
            )
            
            # Update last used timestamp
            credential.last_used_at = datetime.utcnow()
            await self.db.commit()
            
            return response
            
        except httpx.HTTPStatusError as e:
            logger.error(f"API error: {e.response.status_code} - {e.response.text}")
            
            # Handle specific error codes
            if e.response.status_code == 401:
                # Token might be invalid, mark credential
                credential.is_valid = False
                await self.db.commit()
                raise AuthenticationError("Credential is no longer valid. Re-authentication required.")
            
            if e.response.status_code == 429:
                raise RateLimitError("API rate limit exceeded. Try again later.")
            
            raise APIResponseError(
                f"API returned error: {e.response.status_code}",
                status_code=e.response.status_code,
                response_body=e.response.text,
            )
        
        except httpx.RequestError as e:
            logger.error(f"Request failed: {e}")
            raise APIExecutionError(f"Request failed: {str(e)}")
    
    async def _get_credential(
        self,
        bron_id: UUID,
        provider: ServiceProvider,
    ) -> Optional[Credential]:
        """Get valid credential for a provider."""
        result = await self.db.execute(
            select(Credential)
            .where(
                Credential.bron_id == bron_id,
                Credential.provider == provider,
                Credential.is_valid == True,
            )
            .order_by(Credential.updated_at.desc())
        )
        return result.scalar_one_or_none()
    
    async def _refresh_token(self, credential: Credential) -> Credential:
        """Refresh an OAuth token."""
        # This would call the provider's token refresh endpoint
        # For now, we'll mark it as needing re-auth if expired
        
        api_info = KNOWN_APIS.get(credential.provider.value)
        if not api_info or api_info.auth_type != "oauth":
            return credential
        
        # Provider-specific refresh logic would go here
        # For demo purposes, we'll just log and return
        logger.info(f"Token refresh needed for {credential.provider.value}")
        
        # In a real implementation:
        # 1. Call the provider's token endpoint with refresh_token
        # 2. Update access_token and token_expires_at
        # 3. Commit to database
        
        return credential
    
    async def _build_headers(
        self,
        credential: Credential,
        extra_headers: Optional[dict[str, str]] = None,
    ) -> dict[str, str]:
        """Build request headers with authentication."""
        headers = {
            "User-Agent": "Bron/1.0",
            "Accept": "application/json",
        }
        
        # Add authentication
        if credential.credential_type == CredentialType.OAUTH_TOKEN:
            headers["Authorization"] = f"Bearer {credential.access_token}"
        elif credential.credential_type == CredentialType.API_KEY:
            # Different APIs use different header names for API keys
            headers["Authorization"] = f"Bearer {credential.api_key}"
        elif credential.credential_type == CredentialType.BEARER_TOKEN:
            headers["Authorization"] = f"Bearer {credential.access_token}"
        
        # Add extra headers
        if extra_headers:
            headers.update(extra_headers)
        
        return headers
    
    async def _make_request(
        self,
        method: HTTPMethod,
        url: str,
        headers: dict[str, str],
        params: Optional[dict[str, Any]] = None,
        json: Optional[dict[str, Any]] = None,
    ) -> APIResponse:
        """Make the HTTP request."""
        logger.info(f"API Request: {method.value} {url}")
        
        response = await self._client.request(
            method=method.value,
            url=url,
            headers=headers,
            params=params,
            json=json,
        )
        
        # Raise for error status codes
        response.raise_for_status()
        
        # Parse response
        try:
            data = response.json()
        except Exception:
            data = response.text
        
        # Extract rate limit info if available
        rate_limit = None
        if "X-RateLimit-Remaining" in response.headers:
            rate_limit = int(response.headers["X-RateLimit-Remaining"])
        
        return APIResponse(
            success=True,
            status_code=response.status_code,
            data=data,
            rate_limit_remaining=rate_limit,
        )
    
    # =========================================================================
    # Convenience Methods for Common APIs
    # =========================================================================
    
    async def gmail_list_messages(
        self,
        bron_id: UUID,
        max_results: int = 10,
        query: Optional[str] = None,
    ) -> APIResponse:
        """List Gmail messages."""
        params = {"maxResults": max_results}
        if query:
            params["q"] = query
        
        return await self.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.GMAIL,
                endpoint="/gmail/v1/users/me/messages",
                method=HTTPMethod.GET,
                params=params,
            ),
        )
    
    async def gmail_get_message(
        self,
        bron_id: UUID,
        message_id: str,
    ) -> APIResponse:
        """Get a specific Gmail message."""
        return await self.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.GMAIL,
                endpoint=f"/gmail/v1/users/me/messages/{message_id}",
                method=HTTPMethod.GET,
                params={"format": "full"},
            ),
        )
    
    async def gmail_send_message(
        self,
        bron_id: UUID,
        raw_message: str,  # Base64 encoded
    ) -> APIResponse:
        """Send a Gmail message."""
        return await self.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.GMAIL,
                endpoint="/gmail/v1/users/me/messages/send",
                method=HTTPMethod.POST,
                body={"raw": raw_message},
            ),
        )
    
    async def calendar_list_events(
        self,
        bron_id: UUID,
        time_min: Optional[datetime] = None,
        time_max: Optional[datetime] = None,
        max_results: int = 10,
    ) -> APIResponse:
        """List Google Calendar events."""
        params = {
            "maxResults": max_results,
            "singleEvents": True,
            "orderBy": "startTime",
        }
        if time_min:
            params["timeMin"] = time_min.isoformat() + "Z"
        if time_max:
            params["timeMax"] = time_max.isoformat() + "Z"
        
        return await self.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.GOOGLE_CALENDAR,
                endpoint="/calendar/v3/calendars/primary/events",
                method=HTTPMethod.GET,
                params=params,
            ),
        )
    
    async def calendar_create_event(
        self,
        bron_id: UUID,
        summary: str,
        start: datetime,
        end: datetime,
        description: Optional[str] = None,
        location: Optional[str] = None,
    ) -> APIResponse:
        """Create a Google Calendar event."""
        body = {
            "summary": summary,
            "start": {"dateTime": start.isoformat(), "timeZone": "UTC"},
            "end": {"dateTime": end.isoformat(), "timeZone": "UTC"},
        }
        if description:
            body["description"] = description
        if location:
            body["location"] = location
        
        return await self.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.GOOGLE_CALENDAR,
                endpoint="/calendar/v3/calendars/primary/events",
                method=HTTPMethod.POST,
                body=body,
            ),
        )
    
    async def weather_get_current(
        self,
        bron_id: UUID,
        city: str,
    ) -> APIResponse:
        """Get current weather for a city."""
        # Get API key from credentials
        credential = await self._get_credential(bron_id, ServiceProvider.OPENAI)
        # Note: Would need OpenWeatherMap credential type
        
        return await self.execute(
            bron_id=bron_id,
            request=APIRequest(
                provider=ServiceProvider.CUSTOM,  # Would be OPENWEATHERMAP
                endpoint="/data/2.5/weather",
                method=HTTPMethod.GET,
                params={"q": city, "units": "imperial"},
            ),
        )


# =========================================================================
# Credential Management Helpers
# =========================================================================

async def check_has_credential(
    db: AsyncSession,
    bron_id: UUID,
    provider: ServiceProvider,
) -> bool:
    """Check if a Bron has valid credentials for a provider."""
    result = await db.execute(
        select(Credential)
        .where(
            Credential.bron_id == bron_id,
            Credential.provider == provider,
            Credential.is_valid == True,
        )
    )
    return result.scalar_one_or_none() is not None


async def store_oauth_credential(
    db: AsyncSession,
    bron_id: UUID,
    provider: ServiceProvider,
    access_token: str,
    refresh_token: Optional[str] = None,
    expires_in: Optional[int] = None,  # seconds
    scopes: Optional[list[str]] = None,
    extra_data: Optional[dict[str, Any]] = None,
) -> Credential:
    """Store OAuth credentials after successful authentication."""
    expires_at = None
    if expires_in:
        expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    
    credential = Credential(
        bron_id=bron_id,
        provider=provider,
        credential_type=CredentialType.OAUTH_TOKEN,
        access_token=access_token,
        refresh_token=refresh_token,
        token_expires_at=expires_at,
        scopes=scopes,
        extra_data=extra_data,
        is_valid=True,
    )
    
    db.add(credential)
    await db.commit()
    await db.refresh(credential)
    
    logger.info(f"Stored OAuth credential for {provider.value} (Bron: {bron_id})")
    return credential


async def store_api_key_credential(
    db: AsyncSession,
    bron_id: UUID,
    provider: ServiceProvider,
    api_key: str,
    provider_name: Optional[str] = None,
    extra_data: Optional[dict[str, Any]] = None,
) -> Credential:
    """Store an API key credential."""
    credential = Credential(
        bron_id=bron_id,
        provider=provider,
        provider_name=provider_name,
        credential_type=CredentialType.API_KEY,
        api_key=api_key,
        extra_data=extra_data,
        is_valid=True,
    )
    
    db.add(credential)
    await db.commit()
    await db.refresh(credential)
    
    logger.info(f"Stored API key for {provider.value} (Bron: {bron_id})")
    return credential


async def revoke_credential(
    db: AsyncSession,
    credential_id: UUID,
) -> bool:
    """Mark a credential as invalid (revoked)."""
    result = await db.execute(
        select(Credential).where(Credential.id == credential_id)
    )
    credential = result.scalar_one_or_none()
    
    if credential:
        credential.is_valid = False
        await db.commit()
        logger.info(f"Revoked credential {credential_id}")
        return True
    
    return False


async def list_credentials(
    db: AsyncSession,
    bron_id: UUID,
) -> list[dict[str, Any]]:
    """List all credentials for a Bron (without sensitive data)."""
    result = await db.execute(
        select(Credential)
        .where(Credential.bron_id == bron_id)
        .order_by(Credential.provider)
    )
    credentials = result.scalars().all()
    
    return [
        {
            "id": str(c.id),
            "provider": c.provider.value,
            "provider_name": c.provider_name,
            "credential_type": c.credential_type.value,
            "is_valid": c.is_valid,
            "scopes": c.scopes,
            "last_used_at": c.last_used_at.isoformat() if c.last_used_at else None,
            "created_at": c.created_at.isoformat(),
        }
        for c in credentials
    ]

