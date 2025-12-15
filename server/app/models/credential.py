"""
Credential model - secure storage for API keys and OAuth tokens.

Note: In production, sensitive credentials should be encrypted at rest
and ideally stored on-device. This model provides the structure for
credential management.
"""

from enum import Enum
from typing import TYPE_CHECKING, Optional, Any
from uuid import UUID
from datetime import datetime

from sqlalchemy import ForeignKey, String, Text, DateTime
from sqlalchemy.dialects.sqlite import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.bron import BronInstance


class CredentialType(str, Enum):
    """Types of credentials that can be stored."""
    
    OAUTH_TOKEN = "oauth_token"       # OAuth access/refresh tokens
    API_KEY = "api_key"               # API keys (OpenAI, Stripe, etc.)
    USERNAME_PASSWORD = "credentials" # Username/password (encrypted)
    BEARER_TOKEN = "bearer_token"     # Bearer tokens
    COOKIE = "cookie"                 # Session cookies


class ServiceProvider(str, Enum):
    """Known service providers for easier integration."""
    
    # Google Services
    GOOGLE = "google"
    GMAIL = "gmail"
    GOOGLE_CALENDAR = "google_calendar"
    GOOGLE_DRIVE = "google_drive"
    
    # Apple Services
    APPLE = "apple"
    ICLOUD = "icloud"
    
    # Microsoft
    MICROSOFT = "microsoft"
    OUTLOOK = "outlook"
    
    # Social
    TWITTER = "twitter"
    FACEBOOK = "facebook"
    INSTAGRAM = "instagram"
    LINKEDIN = "linkedin"
    
    # Development
    GITHUB = "github"
    GITLAB = "gitlab"
    
    # Communication
    SLACK = "slack"
    DISCORD = "discord"
    ZOOM = "zoom"
    
    # Productivity
    NOTION = "notion"
    TODOIST = "todoist"
    TRELLO = "trello"
    ASANA = "asana"
    
    # Finance
    STRIPE = "stripe"
    PLAID = "plaid"
    VENMO = "venmo"
    
    # Travel
    BOOKING = "booking"
    AIRBNB = "airbnb"
    UBER = "uber"
    LYFT = "lyft"
    
    # Food
    DOORDASH = "doordash"
    UBEREATS = "ubereats"
    GRUBHUB = "grubhub"
    
    # AI/APIs
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    
    # Generic
    CUSTOM = "custom"


class Credential(Base, UUIDMixin, TimestampMixin):
    """
    Credential model for storing API keys and OAuth tokens.
    
    Security notes:
    - Sensitive fields (token, api_key, password) should be encrypted
    - Token refresh should be handled automatically
    - Expired credentials should be cleaned up
    """
    
    __tablename__ = "credentials"
    
    # Service identification
    provider: Mapped[ServiceProvider] = mapped_column(
        String(50),
        nullable=False,
    )
    provider_name: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )  # Human-readable name if custom
    
    # Credential type
    credential_type: Mapped[CredentialType] = mapped_column(
        String(30),
        nullable=False,
    )
    
    # OAuth tokens (encrypted in production)
    access_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    refresh_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    token_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    
    # API keys (encrypted in production)
    api_key: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Scopes/permissions granted
    scopes: Mapped[Optional[list[str]]] = mapped_column(JSON, nullable=True)
    
    # Additional info (e.g., account email, user ID)
    extra_data: Mapped[Optional[dict[str, Any]]] = mapped_column(JSON, nullable=True)
    
    # Status
    is_valid: Mapped[bool] = mapped_column(default=True, nullable=False)
    last_used_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    
    # Owner
    bron_id: Mapped[UUID] = mapped_column(ForeignKey("brons.id"), nullable=False)
    bron: Mapped["BronInstance"] = relationship("BronInstance", back_populates="credentials")
    
    @property
    def is_expired(self) -> bool:
        """Check if the token is expired."""
        if self.token_expires_at is None:
            return False
        return datetime.utcnow() > self.token_expires_at
    
    @property
    def needs_refresh(self) -> bool:
        """Check if the token should be refreshed (within 5 min of expiry)."""
        if self.token_expires_at is None:
            return False
        from datetime import timedelta
        buffer = timedelta(minutes=5)
        return datetime.utcnow() > (self.token_expires_at - buffer)
    
    def __repr__(self) -> str:
        return f"<Credential {self.provider.value} for Bron {self.bron_id}>"

