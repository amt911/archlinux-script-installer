from abc import ABC, abstractmethod
from typing import Any, Dict, TYPE_CHECKING

if TYPE_CHECKING:
    from .action_context import ActionContext

class AbstractAction(ABC):
    """Base class for all system configuration actions.
    
    This class provides the framework for idempotent operations:
    - is_needed(): Check if action needs to run (idempotency check)
    - execute(): Perform the actual configuration changes
    - verify(): Verify the changes were applied correctly
    """
    
    def __init__(self, config: Dict[str, Any], context: 'ActionContext | None' = None):
        """Initialize action with configuration and shared context.
        
        Args:
            config: Configuration dictionary for this action
            context: Shared context between actions (optional)
        """
        self.config = config
        self.context = context
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable name for this action."""
        ...
    
    @property
    def is_optional(self) -> bool:
        """Whether this action can be skipped if config is missing.
        
        Override this to return True for optional actions.
        """
        return False
    
    @abstractmethod
    def is_needed(self) -> bool:
        """Check if this action needs to be executed.
        
        This is the idempotency check - return True if the system
        state differs from desired configuration.
        
        Returns:
            True if action needs to run, False if already configured
        """
        ...
    
    @abstractmethod
    def execute(self) -> None:
        """Execute the configuration changes.
        
        This should only be called if is_needed() returns True.
        Raises exception on failure.
        """
        ...
    
    def verify(self) -> bool:
        """Verify the configuration was applied correctly.
        
        Override this to add verification logic after execution.
        
        Returns:
            True if verification passed, False otherwise
        """
        return True
    
    def do_action(self) -> None:
        """Legacy method for backward compatibility.
        
        This method calls execute() directly without idempotency checks.
        New code should use is_needed() + execute() instead.
        """
        self.execute()
    
    # Deprecated methods - kept for backward compatibility
    def _before_check(self) -> bool:
        """Deprecated: Use is_needed() instead."""
        return self.is_needed()
    
    def after_check(self):
        """Deprecated: Use verify() instead."""
        return self.verify()
    
    @property
    def can_incrementally_change(self) -> bool:
        """Deprecated: No longer used in new architecture."""
        return False
    
    @property
    def KEY_NAME(self) -> str:
        """Deprecated: Use name property instead."""
        return self.name