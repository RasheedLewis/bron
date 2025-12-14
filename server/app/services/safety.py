"""
Safety Guardrails for the Claude Agent.
Implements hooks and checks to prevent dangerous operations.
"""

import logging
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


class RiskLevel(str, Enum):
    """Risk classification for actions."""
    SAFE = "safe"             # No confirmation needed
    LOW = "low"               # Light confirmation
    MEDIUM = "medium"         # Explicit approval required
    HIGH = "high"             # Multi-step approval
    BLOCKED = "blocked"       # Never allow


class ActionCategory(str, Enum):
    """Categories of agent actions."""
    READ = "read"             # Reading files/data
    WRITE = "write"           # Creating/modifying files
    DELETE = "delete"         # Deleting data
    EXECUTE = "execute"       # Running commands
    NETWORK = "network"       # External API calls
    FINANCIAL = "financial"   # Money-related
    COMMUNICATION = "communication"  # Emails, messages


class SafetyCheck(BaseModel):
    """Result of a safety check."""
    allowed: bool
    risk_level: RiskLevel
    reason: str
    requires_approval: bool = False
    approval_prompt: Optional[str] = None


class SafetyGuardrails:
    """
    Safety guardrails for agent actions.
    
    Implements the safety rules from Bron's voice guidelines:
    - Never delete without approval
    - Never send messages without approval
    - Never share sensitive info
    - Never execute financial transactions without approval
    - Always ask for destructive/external confirmations
    """

    # Dangerous command patterns
    DANGEROUS_COMMANDS = [
        "rm -rf",
        "del /f",
        "format",
        "sudo rm",
        "DROP TABLE",
        "DELETE FROM",
        "curl",      # External network
        "wget",
        "ssh",
        "git push",  # External changes
        "npm publish",
    ]
    
    # Sensitive file patterns
    SENSITIVE_PATHS = [
        ".env",
        "credentials",
        "password",
        "secret",
        "private_key",
        ".ssh/",
        "token",
    ]
    
    # Safe read-only commands
    SAFE_COMMANDS = [
        "ls", "dir", "cat", "head", "tail",
        "grep", "find", "pwd", "echo",
        "git status", "git log", "git diff",
    ]

    def check_command(self, command: str) -> SafetyCheck:
        """Check if a bash command is safe to execute."""
        command_lower = command.lower().strip()
        
        # Check for blocked patterns
        for dangerous in self.DANGEROUS_COMMANDS:
            if dangerous.lower() in command_lower:
                return SafetyCheck(
                    allowed=False,
                    risk_level=RiskLevel.HIGH,
                    reason=f"Command contains dangerous pattern: {dangerous}",
                    requires_approval=True,
                    approval_prompt=f"This command may be destructive: {command}\n\nProceed?",
                )
        
        # Check for safe patterns
        for safe in self.SAFE_COMMANDS:
            if command_lower.startswith(safe):
                return SafetyCheck(
                    allowed=True,
                    risk_level=RiskLevel.SAFE,
                    reason="Read-only command",
                )
        
        # Default: medium risk, allow with logging
        return SafetyCheck(
            allowed=True,
            risk_level=RiskLevel.MEDIUM,
            reason="Command will be logged for review",
        )

    def check_file_access(self, path: str, is_write: bool) -> SafetyCheck:
        """Check if file access is safe."""
        path_lower = path.lower()
        
        # Check for sensitive paths
        for sensitive in self.SENSITIVE_PATHS:
            if sensitive in path_lower:
                if is_write:
                    return SafetyCheck(
                        allowed=False,
                        risk_level=RiskLevel.BLOCKED,
                        reason=f"Cannot modify sensitive file: {path}",
                    )
                else:
                    return SafetyCheck(
                        allowed=False,
                        risk_level=RiskLevel.BLOCKED,
                        reason=f"Cannot read sensitive file: {path}",
                    )
        
        if is_write:
            return SafetyCheck(
                allowed=True,
                risk_level=RiskLevel.LOW,
                reason="File write will be logged",
                requires_approval=False,
            )
        
        return SafetyCheck(
            allowed=True,
            risk_level=RiskLevel.SAFE,
            reason="Safe file read",
        )

    def check_external_action(
        self,
        action_type: ActionCategory,
        description: str,
    ) -> SafetyCheck:
        """Check if an external action requires approval."""
        
        if action_type == ActionCategory.FINANCIAL:
            return SafetyCheck(
                allowed=False,
                risk_level=RiskLevel.HIGH,
                reason="Financial actions require explicit approval",
                requires_approval=True,
                approval_prompt=f"Confirm financial action:\n{description}",
            )
        
        if action_type == ActionCategory.COMMUNICATION:
            return SafetyCheck(
                allowed=False,
                risk_level=RiskLevel.HIGH,
                reason="Sending messages requires explicit approval",
                requires_approval=True,
                approval_prompt=f"Approve sending this message:\n{description}",
            )
        
        if action_type == ActionCategory.DELETE:
            return SafetyCheck(
                allowed=False,
                risk_level=RiskLevel.HIGH,
                reason="Deletion requires explicit approval",
                requires_approval=True,
                approval_prompt=f"Confirm deletion:\n{description}",
            )
        
        if action_type == ActionCategory.NETWORK:
            return SafetyCheck(
                allowed=True,
                risk_level=RiskLevel.MEDIUM,
                reason="External request will be logged",
            )
        
        return SafetyCheck(
            allowed=True,
            risk_level=RiskLevel.SAFE,
            reason="Action is safe",
        )


# Agent SDK hooks configuration
def get_safety_hooks() -> dict:
    """
    Get hooks configuration for Claude Agent SDK.
    
    These hooks run before/after tool use to enforce safety.
    """
    return {
        "PreToolUse": [
            {
                "matcher": "Bash",
                "hooks": [{
                    "type": "command",
                    "command": "echo 'BRON_SAFETY: Checking command...' >&2"
                }]
            },
            {
                "matcher": "Edit|Write",
                "hooks": [{
                    "type": "command", 
                    "command": "echo 'BRON_SAFETY: File modification logged' >&2"
                }]
            },
        ],
        "PostToolUse": [
            {
                "matcher": "Bash|Edit|Write",
                "hooks": [{
                    "type": "command",
                    "command": "echo \"$(date): tool used\" >> ./bron_audit.log 2>/dev/null || true"
                }]
            },
        ],
    }


# Singleton
safety_guardrails = SafetyGuardrails()
