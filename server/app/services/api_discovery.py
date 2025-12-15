"""
API Discovery Service - helps Claude find and use APIs.

This service provides:
1. API discovery - search for APIs that can accomplish tasks
2. API documentation lookup - get usage info for specific APIs
3. API execution - make calls to external APIs
"""

import logging
from typing import Any, Optional
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)


class APICategory(str, Enum):
    """Categories of APIs."""
    
    TRAVEL = "travel"
    FINANCE = "finance"
    COMMUNICATION = "communication"
    SOCIAL = "social"
    PRODUCTIVITY = "productivity"
    ENTERTAINMENT = "entertainment"
    FOOD = "food"
    TRANSPORT = "transport"
    WEATHER = "weather"
    SEARCH = "search"
    AI = "ai"
    OTHER = "other"


@dataclass
class APIInfo:
    """Information about an API."""
    
    name: str
    provider: str
    description: str
    category: APICategory
    auth_type: str  # oauth, api_key, none
    oauth_provider: Optional[str] = None  # google, apple, etc.
    base_url: Optional[str] = None
    docs_url: Optional[str] = None
    scopes: Optional[list[str]] = None
    rate_limits: Optional[str] = None


# Known APIs database (would be much larger in production)
KNOWN_APIS: dict[str, APIInfo] = {
    # Google Services
    "gmail": APIInfo(
        name="Gmail API",
        provider="google",
        description="Read, send, and manage email",
        category=APICategory.COMMUNICATION,
        auth_type="oauth",
        oauth_provider="google",
        base_url="https://gmail.googleapis.com",
        docs_url="https://developers.google.com/gmail/api",
        scopes=["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send"],
    ),
    "google_calendar": APIInfo(
        name="Google Calendar API",
        provider="google",
        description="Manage calendar events and schedules",
        category=APICategory.PRODUCTIVITY,
        auth_type="oauth",
        oauth_provider="google",
        base_url="https://www.googleapis.com/calendar/v3",
        docs_url="https://developers.google.com/calendar",
        scopes=["https://www.googleapis.com/auth/calendar"],
    ),
    "google_drive": APIInfo(
        name="Google Drive API",
        provider="google",
        description="Store and access files",
        category=APICategory.PRODUCTIVITY,
        auth_type="oauth",
        oauth_provider="google",
        base_url="https://www.googleapis.com/drive/v3",
        docs_url="https://developers.google.com/drive",
        scopes=["https://www.googleapis.com/auth/drive"],
    ),
    
    # Travel - Hotels
    "booking": APIInfo(
        name="Booking.com",
        provider="booking",
        description="Search and book hotels worldwide",
        category=APICategory.TRAVEL,
        auth_type="api_key",
        base_url="https://distribution-xml.booking.com",
        docs_url="https://developers.booking.com",
    ),
    "hotels_com": APIInfo(
        name="Hotels.com",
        provider="hotels_com",
        description="Hotel search and booking",
        category=APICategory.TRAVEL,
        auth_type="api_key",
        base_url="https://api.hotels.com",
        docs_url="https://developer.hotels.com",
    ),
    "airbnb": APIInfo(
        name="Airbnb",
        provider="airbnb",
        description="Book vacation rentals and unique stays",
        category=APICategory.TRAVEL,
        auth_type="oauth",
        oauth_provider="airbnb",
        base_url="https://api.airbnb.com",
        docs_url="https://developer.airbnb.com",
    ),
    
    # Travel - Flights
    "amadeus": APIInfo(
        name="Amadeus",
        provider="amadeus",
        description="Flight search, booking, and travel data",
        category=APICategory.TRAVEL,
        auth_type="api_key",
        base_url="https://api.amadeus.com",
        docs_url="https://developers.amadeus.com",
    ),
    "skyscanner": APIInfo(
        name="Skyscanner",
        provider="skyscanner",
        description="Compare flight prices across airlines",
        category=APICategory.TRAVEL,
        auth_type="api_key",
        base_url="https://partners.api.skyscanner.net",
        docs_url="https://developers.skyscanner.net",
    ),
    "kiwi": APIInfo(
        name="Kiwi.com",
        provider="kiwi",
        description="Flight search with flexible dates and routes",
        category=APICategory.TRAVEL,
        auth_type="api_key",
        base_url="https://api.tequila.kiwi.com",
        docs_url="https://tequila.kiwi.com/docs",
    ),
    
    # Travel - Car Rental
    "rentalcars": APIInfo(
        name="Rentalcars.com",
        provider="rentalcars",
        description="Car rental comparison and booking",
        category=APICategory.TRAVEL,
        auth_type="api_key",
        base_url="https://api.rentalcars.com",
        docs_url="https://developer.rentalcars.com",
    ),
    
    # Transport - Rideshare
    "uber": APIInfo(
        name="Uber",
        provider="uber",
        description="Request rides",
        category=APICategory.TRANSPORT,
        auth_type="oauth",
        oauth_provider="uber",
        base_url="https://api.uber.com",
        docs_url="https://developer.uber.com",
    ),
    "lyft": APIInfo(
        name="Lyft",
        provider="lyft",
        description="Request rides",
        category=APICategory.TRANSPORT,
        auth_type="oauth",
        oauth_provider="lyft",
        base_url="https://api.lyft.com",
        docs_url="https://developer.lyft.com",
    ),
    
    # Finance
    "stripe": APIInfo(
        name="Stripe API",
        provider="stripe",
        description="Process payments",
        category=APICategory.FINANCE,
        auth_type="api_key",
        base_url="https://api.stripe.com",
        docs_url="https://stripe.com/docs/api",
    ),
    "plaid": APIInfo(
        name="Plaid API",
        provider="plaid",
        description="Connect bank accounts",
        category=APICategory.FINANCE,
        auth_type="api_key",
        base_url="https://plaid.com",
        docs_url="https://plaid.com/docs",
    ),
    
    # Communication
    "slack": APIInfo(
        name="Slack API",
        provider="slack",
        description="Send messages and manage workspaces",
        category=APICategory.COMMUNICATION,
        auth_type="oauth",
        oauth_provider="slack",
        base_url="https://slack.com/api",
        docs_url="https://api.slack.com",
    ),
    "twilio": APIInfo(
        name="Twilio API",
        provider="twilio",
        description="Send SMS and make calls",
        category=APICategory.COMMUNICATION,
        auth_type="api_key",
        base_url="https://api.twilio.com",
        docs_url="https://www.twilio.com/docs",
    ),
    
    # Food
    "doordash": APIInfo(
        name="DoorDash API",
        provider="doordash",
        description="Order food delivery",
        category=APICategory.FOOD,
        auth_type="oauth",
        oauth_provider="doordash",
        base_url="https://api.doordash.com",
        docs_url="https://developer.doordash.com",
    ),
    "ubereats": APIInfo(
        name="Uber Eats API",
        provider="uber",
        description="Order food delivery",
        category=APICategory.FOOD,
        auth_type="oauth",
        oauth_provider="uber",
        base_url="https://api.uber.com/eats",
        docs_url="https://developer.uber.com",
    ),
    
    # Weather
    "openweathermap": APIInfo(
        name="OpenWeatherMap API",
        provider="openweathermap",
        description="Get weather data",
        category=APICategory.WEATHER,
        auth_type="api_key",
        base_url="https://api.openweathermap.org",
        docs_url="https://openweathermap.org/api",
    ),
    
    # AI
    "openai": APIInfo(
        name="OpenAI API",
        provider="openai",
        description="AI text generation and analysis",
        category=APICategory.AI,
        auth_type="api_key",
        base_url="https://api.openai.com",
        docs_url="https://platform.openai.com/docs",
    ),
}


class APIDiscoveryService:
    """Service for discovering and managing API integrations."""
    
    def search_apis(
        self,
        query: str,
        category: Optional[APICategory] = None,
    ) -> list[APIInfo]:
        """
        Search for APIs that match a query.
        
        Args:
            query: Search query (e.g., "book hotel", "send email")
            category: Optional category filter
            
        Returns:
            List of matching APIs
        """
        query_lower = query.lower()
        results = []
        
        # Keyword mappings for common tasks
        task_to_apis = {
            # Email & Communication
            "email": ["gmail"],
            "mail": ["gmail"],
            "message": ["slack", "twilio"],
            "slack": ["slack"],
            "sms": ["twilio"],
            "text": ["twilio"],
            
            # Calendar
            "calendar": ["google_calendar"],
            "schedule": ["google_calendar"],
            "meeting": ["google_calendar"],
            "appointment": ["google_calendar"],
            
            # Travel - Hotels
            "hotel": ["booking", "hotels_com"],
            "book hotel": ["booking"],
            "accommodation": ["booking", "airbnb"],
            "airbnb": ["airbnb"],
            "stay": ["booking", "airbnb"],
            "lodging": ["booking"],
            
            # Travel - Flights
            "flight": ["amadeus", "skyscanner", "kiwi"],
            "fly": ["amadeus", "skyscanner"],
            "book flight": ["amadeus"],
            "plane": ["amadeus", "skyscanner"],
            "airline": ["amadeus"],
            "travel": ["amadeus", "booking"],
            "trip": ["amadeus", "booking"],
            
            # Travel - Car
            "car rental": ["rentalcars"],
            "rent car": ["rentalcars"],
            "rental car": ["rentalcars"],
            
            # Transport
            "ride": ["uber", "lyft"],
            "taxi": ["uber", "lyft"],
            "uber": ["uber"],
            "lyft": ["lyft"],
            
            # Finance
            "payment": ["stripe"],
            "pay": ["stripe"],
            "bank": ["plaid"],
            
            # Food
            "food": ["doordash", "ubereats"],
            "delivery": ["doordash", "ubereats"],
            "order food": ["doordash", "ubereats"],
            "restaurant": ["doordash"],
            
            # Productivity
            "weather": ["openweathermap"],
            "files": ["google_drive"],
            "drive": ["google_drive"],
            "document": ["google_drive"],
        }
        
        # Search by task keywords
        for keyword, api_ids in task_to_apis.items():
            if keyword in query_lower:
                for api_id in api_ids:
                    if api_id in KNOWN_APIS:
                        api = KNOWN_APIS[api_id]
                        if category is None or api.category == category:
                            if api not in results:
                                results.append(api)
        
        # Also search by API name/description
        for api_id, api in KNOWN_APIS.items():
            if query_lower in api.name.lower() or query_lower in api.description.lower():
                if category is None or api.category == category:
                    if api not in results:
                        results.append(api)
        
        return results
    
    def get_api_info(self, provider: str) -> Optional[APIInfo]:
        """Get information about a specific API."""
        return KNOWN_APIS.get(provider.lower())
    
    def get_best_api(self, query: str) -> Optional[APIInfo]:
        """
        Get the single best API for a task. Auto-selects based on:
        1. OAuth preference (more secure than passwords)
        2. Reliability/popularity of service
        3. Feature match
        
        Args:
            query: What the user wants to do (e.g., "book hotel", "send email")
            
        Returns:
            The recommended API, or None if no match
        """
        results = self.search_apis(query)
        if not results:
            return None
        
        # Score each API
        def score_api(api: APIInfo) -> int:
            score = 0
            # Prefer OAuth (more secure, better UX)
            if api.auth_type == "oauth":
                score += 10
            # Prefer well-known providers
            trusted_providers = ["google", "apple", "microsoft", "stripe"]
            if api.provider in trusted_providers:
                score += 5
            # Prefer APIs with docs
            if api.docs_url:
                score += 2
            return score
        
        # Sort by score (highest first) and return best
        results.sort(key=score_api, reverse=True)
        return results[0]
    
    def get_recommended_service(self, task_type: str) -> dict[str, Any]:
        """
        Get the recommended service for a task type with all relevant info.
        
        Args:
            task_type: Type of task (hotel, flight, email, calendar, payment, etc.)
            
        Returns:
            Dict with provider, auth_type, and UI component to use
        """
        # Direct mappings for common tasks - pick the BEST default service
        task_defaults = {
            # Travel
            "hotel": "booking",
            "accommodation": "booking",
            "stay": "booking",
            "airbnb": "airbnb",
            "flight": "amadeus",        # Amadeus is the industry standard
            "fly": "amadeus",
            "plane": "amadeus",
            "travel": "amadeus",
            "trip": "amadeus",
            "car rental": "rentalcars",
            "rental": "rentalcars",
            
            # Transport
            "ride": "uber",
            "taxi": "uber",
            "lyft": "lyft",
            
            # Communication
            "email": "gmail",
            "mail": "gmail",
            "message": "slack",
            "sms": "twilio",
            
            # Calendar
            "calendar": "google_calendar",
            "schedule": "google_calendar",
            "meeting": "google_calendar",
            "appointment": "google_calendar",
            
            # Finance
            "payment": "stripe",
            "pay": "stripe",
            "bank": "plaid",
            
            # Food
            "food": "doordash",
            "delivery": "doordash",
            "restaurant": "doordash",
            
            # Productivity
            "weather": "openweathermap",
            "files": "google_drive",
            "documents": "google_drive",
            "drive": "google_drive",
        }
        
        provider_id = task_defaults.get(task_type.lower())
        if not provider_id:
            # Fall back to search
            api = self.get_best_api(task_type)
            if api:
                provider_id = api.provider
        
        if not provider_id:
            return {"provider": None, "error": "No service found for this task"}
        
        api = KNOWN_APIS.get(provider_id)
        if not api:
            return {"provider": provider_id, "error": "Service not configured"}
        
        return {
            "provider": api.provider,
            "provider_name": api.name,
            "auth_type": api.auth_type,
            "auth_ui_component": self._get_auth_component(api),
            "scopes": api.scopes,
        }
    
    def _get_auth_component(self, api: APIInfo) -> str:
        """Get the appropriate UI component for authentication."""
        if api.auth_type == "oauth":
            if api.oauth_provider == "google":
                return "auth_google"
            elif api.oauth_provider == "apple":
                return "auth_apple"
            else:
                return "auth_oauth"
        elif api.auth_type == "api_key":
            return "api_key_input"
        else:
            return "credentials_input"
    
    def get_required_auth(self, provider: str) -> dict[str, Any]:
        """
        Get authentication requirements for an API.
        
        Returns dict with:
        - auth_type: oauth, api_key, or none
        - oauth_provider: if oauth, which provider
        - scopes: required OAuth scopes
        - ui_component: suggested UI component type
        """
        api = self.get_api_info(provider)
        if not api:
            return {"auth_type": "unknown", "ui_component": "credentials_input"}
        
        result = {
            "auth_type": api.auth_type,
            "scopes": api.scopes,
        }
        
        if api.auth_type == "oauth":
            result["oauth_provider"] = api.oauth_provider
            # Map to UI components
            if api.oauth_provider == "google":
                result["ui_component"] = "auth_google"
            elif api.oauth_provider == "apple":
                result["ui_component"] = "auth_apple"
            else:
                result["ui_component"] = "auth_oauth"
        elif api.auth_type == "api_key":
            result["ui_component"] = "api_key_input"
        else:
            result["ui_component"] = None
        
        return result
    
    def list_categories(self) -> list[str]:
        """List all API categories."""
        return [c.value for c in APICategory]


# Singleton instance
api_discovery = APIDiscoveryService()

