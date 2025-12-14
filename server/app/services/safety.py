"""
Safety Guardrails for Bron Agent.
Ensures no destructive or unauthorized actions are taken.
"""

import re
import logging
from typing import Optional
from enum import Enum

logger = logging.getLogger(__name__)


class RiskLevel(str, Enum):
    """Risk level of an action."""
    SAFE = "safe"           # Can proceed without confirmation
    LOW = "low"             # Minor risk, soft confirmation
    MEDIUM = "medium"       # Needs explicit confirmation
    HIGH = "high"           # Needs approval with details
    BLOCKED = "blocked"     # Never allowed


class ActionCategory(str, Enum):
    """Category of action for safety classification."""
    READ = "read"           # Reading data
    CREATE = "create"       # Creating new items
    UPDATE = "update"       # Modifying existing items
    DELETE = "delete"       # Removing items
    SEND = "send"           # Sending messages/communications
    EXECUTE = "execute"     # Executing external actions
    AUTHENTICATE = "auth"   # Authentication flows
    FINANCIAL = "financial" # Financial transactions


# Keywords that indicate potentially risky actions
RISK_KEYWORDS = {
    RiskLevel.BLOCKED: [
        "rm -rf",
        "format disk",
        "delete all",
        "drop database",
        "truncate",
    ],
    RiskLevel.HIGH: [
        "delete", "remove", "erase", "destroy", "purge",
        "send email", "send message", "post to", "publish",
        "pay", "transfer money", "purchase", "buy", "charge",
        "cancel subscription", "terminate", "unsubscribe",
        "share password", "share secret", "expose",
    ],
    RiskLevel.MEDIUM: [
        "update", "modify", "change", "edit",
        "move", "rename", "archive",
        "schedule", "book", "reserve",
        "reply", "respond to",
    ],
    RiskLevel.LOW: [
        "draft", "prepare", "create",
        "save", "store",
        "read", "fetch", "get",
    ],
}

# Actions that are always blocked
BLOCKED_ACTIONS = [
    r"delete\s+(all|every|entire)",
    r"rm\s+-rf",
    r"format\s+\w+",
    r"drop\s+(table|database)",
    r"share\s+(password|secret|key|token)",
    r"expose\s+(credentials|secrets)",
]

# Sensitive data patterns that should never be transmitted
SENSITIVE_PATTERNS = [
    r"\b\d{16}\b",  # Credit card numbers
    r"\b\d{3}-\d{2}-\d{4}\b",  # SSN
    r"\bpassword\s*[:=]\s*\S+",  # Passwords in plain text
    r"\b(api[_-]?key|secret[_-]?key)\s*[:=]\s*\S+",  # API keys
]


class SafetyGuard:
    """
    Safety guard for agent actions.
    
    Analyzes messages and actions to determine risk level
    and whether confirmation/approval is needed.
    """

    def analyze_message(self, message: str) -> tuple[RiskLevel, list[str]]:
        """
        Analyze a message for risk level.
        
        Args:
            message: The message to analyze
            
        Returns:
            Tuple of (risk level, list of flagged items)
        """
        message_lower = message.lower()
        flagged = []
        
        # Check for blocked patterns
        for pattern in BLOCKED_ACTIONS:
            if re.search(pattern, message_lower):
                flagged.append(f"Blocked pattern: {pattern}")
                return RiskLevel.BLOCKED, flagged
        
        # Check for sensitive data
        for pattern in SENSITIVE_PATTERNS:
            if re.search(pattern, message):
                flagged.append(f"Sensitive data detected")
                return RiskLevel.BLOCKED, flagged
        
        # Check risk keywords (highest matching level wins)
        highest_risk = RiskLevel.SAFE
        
        for risk_level in [RiskLevel.HIGH, RiskLevel.MEDIUM, RiskLevel.LOW]:
            for keyword in RISK_KEYWORDS[risk_level]:
                if keyword in message_lower:
                    flagged.append(f"Keyword '{keyword}' detected")
                    if self._risk_level_value(risk_level) > self._risk_level_value(highest_risk):
                        highest_risk = risk_level
        
        return highest_risk, flagged

    def categorize_action(self, action_description: str) -> ActionCategory:
        """
        Categorize an action.
        
        Args:
            action_description: Description of the action
            
        Returns:
            ActionCategory
        """
        action_lower = action_description.lower()
        
        if any(word in action_lower for word in ["delete", "remove", "erase"]):
            return ActionCategory.DELETE
        if any(word in action_lower for word in ["send", "email", "message", "post"]):
            return ActionCategory.SEND
        if any(word in action_lower for word in ["pay", "transfer", "purchase", "buy"]):
            return ActionCategory.FINANCIAL
        if any(word in action_lower for word in ["login", "sign in", "authenticate", "connect"]):
            return ActionCategory.AUTHENTICATE
        if any(word in action_lower for word in ["run", "execute", "trigger"]):
            return ActionCategory.EXECUTE
        if any(word in action_lower for word in ["update", "modify", "change", "edit"]):
            return ActionCategory.UPDATE
        if any(word in action_lower for word in ["create", "add", "new"]):
            return ActionCategory.CREATE
        
        return ActionCategory.READ

    def requires_confirmation(
        self,
        risk_level: RiskLevel,
        action_category: ActionCategory,
    ) -> bool:
        """
        Determine if an action requires confirmation.
        
        Args:
            risk_level: The risk level of the action
            action_category: The category of action
            
        Returns:
            True if confirmation is required
        """
        # Always block blocked actions
        if risk_level == RiskLevel.BLOCKED:
            return True  # Will be blocked, not just confirmed
        
        # High risk always needs confirmation
        if risk_level == RiskLevel.HIGH:
            return True
        
        # Medium risk needs confirmation for certain categories
        if risk_level == RiskLevel.MEDIUM:
            return action_category in [
                ActionCategory.DELETE,
                ActionCategory.SEND,
                ActionCategory.FINANCIAL,
                ActionCategory.EXECUTE,
            ]
        
        # These categories always need confirmation regardless of risk
        if action_category in [ActionCategory.DELETE, ActionCategory.FINANCIAL]:
            return True
        
        return False

    def get_confirmation_type(
        self,
        risk_level: RiskLevel,
        action_category: ActionCategory,
    ) -> str:
        """
        Get the type of confirmation UI needed.
        
        Args:
            risk_level: The risk level
            action_category: The action category
            
        Returns:
            UI component type for confirmation
        """
        if risk_level == RiskLevel.BLOCKED:
            return "error"  # Show error, don't allow
        
        if risk_level == RiskLevel.HIGH or action_category == ActionCategory.FINANCIAL:
            return "approval"
        
        return "confirmation"

    def sanitize_output(self, text: str) -> str:
        """
        Sanitize output to remove sensitive information.
        
        Args:
            text: Text to sanitize
            
        Returns:
            Sanitized text
        """
        result = text
        
        for pattern in SENSITIVE_PATTERNS:
            result = re.sub(pattern, "[REDACTED]", result)
        
        return result

    def validate_external_action(
        self,
        action_type: str,
        target: str,
        data: Optional[dict] = None,
    ) -> tuple[bool, str]:
        """
        Validate an external action before execution.
        
        Args:
            action_type: Type of action (send_email, api_call, etc.)
            target: Target of the action (email address, URL, etc.)
            data: Optional data payload
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        # Block certain action types entirely
        blocked_types = ["delete_account", "format_device", "system_command"]
        if action_type in blocked_types:
            return False, f"Action type '{action_type}' is not allowed"
        
        # Validate data doesn't contain sensitive patterns
        if data:
            data_str = str(data)
            for pattern in SENSITIVE_PATTERNS:
                if re.search(pattern, data_str):
                    return False, "Data contains sensitive information that cannot be transmitted"
        
        return True, ""

    def _risk_level_value(self, level: RiskLevel) -> int:
        """Get numeric value for risk level comparison."""
        values = {
            RiskLevel.SAFE: 0,
            RiskLevel.LOW: 1,
            RiskLevel.MEDIUM: 2,
            RiskLevel.HIGH: 3,
            RiskLevel.BLOCKED: 4,
        }
        return values.get(level, 0)


# Singleton instance
safety_guard = SafetyGuard()

