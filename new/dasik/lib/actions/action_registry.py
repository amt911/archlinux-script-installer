from typing import Dict, Type, List, Any, Optional
from .abstract_action import AbstractAction

class ActionRegistry:
    """Registry for managing available system configuration actions.
    
    This allows adding new actions without modifying the main handler.
    Actions are registered with their configuration key and optional
    validation function.
    """
    
    def __init__(self):
        """Initialize empty registry."""
        self._actions: List[Dict[str, Any]] = []
    
    def register(
        self,
        action_class: Type[AbstractAction],
        config_key: str,
        is_optional: bool = False,
        required_fields: Optional[List[str]] = None,
        depends_on: Optional[List[str]] = None
    ) -> None:
        """Register an action with the registry.
        
        Args:
            action_class: The action class to register
            config_key: Key in JSON config for this action (e.g., 'disks', 'timezone')
            is_optional: Whether this action can be skipped if config is missing
            required_fields: List of required fields within the config section
            depends_on: List of config keys this action depends on
        """
        self._actions.append({
            'class': action_class,
            'config_key': config_key,
            'is_optional': is_optional,
            'required_fields': required_fields or [],
            'depends_on': depends_on or []
        })
    
    def get_all_actions(self) -> List[Dict[str, Any]]:
        """Get all registered actions.
        
        Returns:
            List of action metadata dictionaries
        """
        return self._actions.copy()
    
    def validate_config(self, config: Dict[str, Any], action_meta: Dict[str, Any]) -> tuple[bool, Optional[str]]:
        """Validate that config has required fields for an action.
        
        Args:
            config: Full configuration dictionary
            action_meta: Action metadata from registry
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        config_key = action_meta['config_key']
        
        # Check if config section exists
        if config_key not in config:
            if action_meta['is_optional']:
                return False, f"Optional section '{config_key}' not found in config"
            else:
                return False, f"Required section '{config_key}' not found in config"
        
        # Check required fields within the section
        if action_meta['required_fields']:
            section_config = config[config_key]
            if isinstance(section_config, dict):
                missing = [f for f in action_meta['required_fields'] if f not in section_config]
                if missing:
                    return False, f"Missing required fields in '{config_key}': {', '.join(missing)}"
        
        # Check dependencies
        if action_meta['depends_on']:
            missing_deps = [dep for dep in action_meta['depends_on'] if dep not in config]
            if missing_deps:
                return False, f"Missing required dependencies: {', '.join(missing_deps)}"
        
        return True, None


# Global registry instance
_default_registry = ActionRegistry()


def get_default_registry() -> ActionRegistry:
    """Get the default global registry.
    
    Returns:
        Default ActionRegistry instance
    """
    return _default_registry


def register_action(
    action_class: Type[AbstractAction],
    config_key: str,
    is_optional: bool = False,
    required_fields: Optional[List[str]] = None,
    depends_on: Optional[List[str]] = None
) -> None:
    """Convenience function to register action with default registry.
    
    Args:
        action_class: The action class to register
        config_key: Key in JSON config for this action
        is_optional: Whether this action can be skipped
        required_fields: List of required fields within the config section
        depends_on: List of config keys this action depends on
    """
    _default_registry.register(
        action_class=action_class,
        config_key=config_key,
        is_optional=is_optional,
        required_fields=required_fields,
        depends_on=depends_on
    )
