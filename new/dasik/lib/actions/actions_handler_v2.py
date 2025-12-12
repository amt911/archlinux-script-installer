"""
New simplified actions handler using registry pattern.

This module provides the new architecture for executing system configuration
actions with idempotency support. It replaces the old monolithic ActionsHandler.

Key improvements:
1. Idempotency: Actions check if changes are needed before executing
2. Scalability: New actions can be added without modifying handler
3. Maintainability: Each action is self-contained
4. Flexibility: Optional actions are handled automatically

Usage:
    from dasik.lib.actions.actions_handler_v2 import setup_actions, execute_installation
    
    # Register all available actions
    setup_actions()
    
    # Execute installation
    success = execute_installation("config.json")
"""

from ..json_parser.json_parser import JsonParser
from .action_registry import register_action
from .action_executor import ActionExecutor


def setup_actions() -> None:
    """Register all available system configuration actions.
    
    This function registers all actions with the global registry.
    Call this once at application startup.
    """
    # Import action classes
    from .disk_partition_action import DiskPartitionAction
    from .timezone_action import TimezoneAction
    from .locale_action import LocaleAction
    from .network_action import NetworkAction
    from .base_install_action import BaseInstallAction
    
    # Register disk partitioning (optional)
    register_action(
        action_class=DiskPartitionAction,
        config_key='disks',
        is_optional=True  # Disks configuration is optional
    )
    
    # Register timezone configuration (optional)
    register_action(
        action_class=TimezoneAction,
        config_key='timezone',
        is_optional=True,
        required_fields=['region', 'city']
    )
    
    # Register locale configuration (optional)
    register_action(
        action_class=LocaleAction,
        config_key='locales',
        is_optional=True,
        required_fields=['selected_locales', 'desired_locale', 'desired_tty_layout']
    )
    
    # Register network configuration (optional)
    register_action(
        action_class=NetworkAction,
        config_key='network',
        is_optional=True,
        required_fields=['type', 'add_default_hosts'],
        depends_on=['hostname']  # Network action needs hostname from root config
    )
    
    # Register base installation (required)
    register_action(
        action_class=BaseInstallAction,
        config_key='__root__',  # Special key indicating this uses root-level config
        is_optional=False,
        required_fields=['enable_microcode']
    )


def execute_installation(config_file: str) -> bool:
    """Execute system installation from configuration file.
    
    Args:
        config_file: Path to JSON configuration file
        
    Returns:
        True if installation succeeded, False otherwise
    """
    # Parse configuration
    parser = JsonParser(config_file)
    config = parser.debug()
    
    # Create executor and run
    executor = ActionExecutor(config)
    return executor.execute_all()


class ActionsHandler:
    """Legacy handler for backward compatibility.
    
    This class maintains the same interface as the old ActionsHandler
    but uses the new architecture internally.
    """
    
    def __init__(self, filename: str):
        """Initialize and execute installation.
        
        Args:
            filename: Path to JSON configuration file
        """
        # Setup actions if not already done
        setup_actions()
        
        # Execute installation
        success = execute_installation(filename)
        
        if not success:
            raise RuntimeError("Installation failed - see errors above")
