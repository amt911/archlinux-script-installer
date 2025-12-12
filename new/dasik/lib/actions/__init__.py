"""Actions module for system configuration.

This module provides both the old monolithic handler and the new
idempotent architecture using action registry pattern.

For new code, use:
    from dasik.lib.actions import setup_actions, execute_installation
    
For backward compatibility:
    from dasik.lib.actions import ActionsHandler
"""

# New architecture (recommended)
from .actions_handler_v2 import (
    setup_actions,
    execute_installation,
    ActionsHandler as ActionsHandlerV2
)

# Legacy handler (backward compatibility)
from .actions_handler import ActionsHandler

# Core classes for extending
from .abstract_action import AbstractAction
from .action_context import ActionContext
from .action_registry import ActionRegistry, register_action
from .action_executor import ActionExecutor

__all__ = [
    # New API
    'setup_actions',
    'execute_installation',
    'ActionsHandlerV2',
    
    # Legacy API
    'ActionsHandler',
    
    # Extension API
    'AbstractAction',
    'ActionContext',
    'ActionRegistry',
    'register_action',
    'ActionExecutor',
]
