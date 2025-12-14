"""
UIRecipe model - dynamic UI generation schema.
"""

from enum import Enum
from typing import TYPE_CHECKING, Optional, Any
from uuid import UUID

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.dialects.sqlite import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.task import Task
    from app.models.chat import ChatMessage


class UIComponentType(str, Enum):
    """
    Types of UI components that can be generated.
    
    Categories:
    - INPUT: Collect structured data from user
    - DISPLAY: Show information (read-only)
    - ACTION: Trigger actions (auth, execute, approve)
    - RICH: Display rich content (emails, calendar, weather)
    """
    
    # === INPUT COMPONENTS ===
    FORM = "form"                       # Multi-field form
    PICKER = "picker"                   # Single selection picker
    MULTI_SELECT = "multi_select"       # Multiple selection
    DATE_PICKER = "date_picker"         # Date/time selection
    CONTACT_PICKER = "contact_picker"   # Contact selection
    FILE_UPLOAD = "file_upload"         # File/photo upload
    LOCATION_PICKER = "location_picker" # Location selection
    
    # === DISPLAY COMPONENTS ===
    INFO_CARD = "info_card"             # Generic information display
    WEATHER = "weather"                 # Weather display
    SUMMARY = "summary"                 # Task/progress summary
    LIST_VIEW = "list_view"             # List of items (read-only)
    PROGRESS = "progress"               # Progress indicator with details
    
    # === ACTION COMPONENTS ===
    CONFIRMATION = "confirmation"       # Yes/No confirmation gate
    APPROVAL = "approval"               # Approve action before execution
    AUTH_GOOGLE = "auth_google"         # Google OAuth sign-in
    AUTH_APPLE = "auth_apple"           # Sign in with Apple
    AUTH_OAUTH = "auth_oauth"           # Generic OAuth flow
    EXECUTE = "execute"                 # Execute action button
    
    # === RICH CONTENT ===
    EMAIL_PREVIEW = "email_preview"     # Email message preview
    EMAIL_COMPOSE = "email_compose"     # Email composition
    CALENDAR_EVENT = "calendar_event"   # Calendar event display/create
    MESSAGE_PREVIEW = "message_preview" # SMS/iMessage preview
    DOCUMENT_PREVIEW = "document_preview"  # Document/PDF preview
    LINK_PREVIEW = "link_preview"       # URL/link preview card


class FieldType(str, Enum):
    """Field types for form schemas and rich content."""
    
    # Basic input types
    TEXT = "text"
    NUMBER = "number"
    DATE = "date"
    DATETIME = "datetime"
    TIME = "time"
    EMAIL = "email"
    PHONE = "phone"
    URL = "url"
    
    # Selection types
    SELECT = "select"
    MULTI_SELECT = "multi_select"
    BOOLEAN = "boolean"
    
    # File types
    FILE = "file"
    IMAGE = "image"
    DOCUMENT = "document"
    
    # Rich content types
    LOCATION = "location"
    CONTACT = "contact"
    CURRENCY = "currency"
    
    # Display-only types (for info cards, previews)
    RICH_TEXT = "rich_text"
    HTML = "html"
    MARKDOWN = "markdown"
    JSON = "json"


class UIStylePreset(str, Enum):
    """Pre-defined style presets for common branding."""
    
    # Platform defaults
    DEFAULT = "default"
    MINIMAL = "minimal"
    
    # Brand presets
    GOOGLE = "google"
    APPLE = "apple"
    MICROSOFT = "microsoft"
    GITHUB = "github"
    SLACK = "slack"
    NOTION = "notion"
    SPOTIFY = "spotify"
    
    # Category-based
    PROFESSIONAL = "professional"
    CASUAL = "casual"
    URGENT = "urgent"
    SUCCESS = "success"
    WARNING = "warning"
    ERROR = "error"
    
    # Content-specific
    EMAIL = "email"
    CALENDAR = "calendar"
    WEATHER = "weather"
    FINANCIAL = "financial"
    HEALTH = "health"


class UIStyle(Base, UUIDMixin):
    """
    Styling configuration for UI Recipes.
    
    Can use a preset or define custom styling.
    """
    
    __tablename__ = "ui_styles"
    
    # Preset (optional - overrides custom values)
    preset: Mapped[Optional[UIStylePreset]] = mapped_column(String(30), nullable=True)
    
    # Colors (hex or CSS color names)
    primary_color: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    secondary_color: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    background_color: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    text_color: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    accent_color: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Typography
    font_family: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    font_weight: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # light, regular, medium, bold
    font_size: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)    # small, medium, large
    
    # Layout
    corner_radius: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # none, small, medium, large, full
    padding: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)        # compact, normal, spacious
    border_style: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)   # none, subtle, prominent
    
    # Effects
    shadow: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)         # none, subtle, medium, prominent
    blur_background: Mapped[bool] = mapped_column(default=False, nullable=False)
    
    # Brand-specific
    logo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    icon_name: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)      # SF Symbol name
    
    def __repr__(self) -> str:
        if self.preset:
            return f"<UIStyle preset={self.preset.value}>"
        return f"<UIStyle custom primary={self.primary_color}>"


class UIRecipe(Base, UUIDMixin, TimestampMixin):
    """
    UIRecipe model for dynamic UI generation.
    
    When a Bron needs structured information to proceed,
    it generates a UI Recipe that the iOS client renders.
    
    Schema example:
    {
        "amount": {"type": "number", "label": "Amount", "required": true},
        "date": {"type": "date", "label": "Receipt Date"},
        "category": {"type": "select", "label": "Category", "options": ["Food", "Transport"]}
    }
    """
    
    __tablename__ = "ui_recipes"
    
    # Component type
    component_type: Mapped[UIComponentType] = mapped_column(
        String(30),
        nullable=False,
    )
    
    # Schema definition (JSON)
    schema: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    
    # Required fields list
    required_fields: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    
    # Display
    title: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Submitted data (filled in when user responds)
    submitted_data: Mapped[Optional[dict[str, Any]]] = mapped_column(JSON, nullable=True)
    is_submitted: Mapped[bool] = mapped_column(default=False, nullable=False)
    
    # Styling
    style_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("ui_styles.id"), nullable=True)
    style: Mapped[Optional["UIStyle"]] = relationship("UIStyle")
    
    # Relationships
    task_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("tasks.id"), nullable=True)
    task: Mapped[Optional["Task"]] = relationship("Task", back_populates="ui_recipes")
    
    message_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("chat_messages.id"), nullable=True)
    message: Mapped[Optional["ChatMessage"]] = relationship("ChatMessage", back_populates="ui_recipe")
    
    def __repr__(self) -> str:
        return f"<UIRecipe {self.id}: {self.component_type.value}>"

