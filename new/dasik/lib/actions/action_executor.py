from typing import Dict, Any, List
from colorama import Fore, Style, init  # type: ignore
from .action_context import ActionContext
from .action_registry import ActionRegistry, get_default_registry


class ActionResult:
    """Result of executing an action."""
    
    def __init__(self, name: str, status: str, message: str = ""):
        """Initialize result.
        
        Args:
            name: Action name
            status: 'success', 'skipped', 'failed', 'not_needed'
            message: Additional information
        """
        self.name = name
        self.status = status
        self.message = message


class ActionExecutor:
    """Executes registered actions with idempotency support.
    
    This executor:
    1. Validates configuration for each action
    2. Checks if action is needed (idempotency)
    3. Executes only when needed
    4. Verifies results
    5. Tracks and reports results
    """
    
    def __init__(self, config: Dict[str, Any], registry: ActionRegistry | None = None):
        """Initialize executor.
        
        Args:
            config: Full configuration dictionary
            registry: Action registry to use (defaults to global registry)
        """
        init(autoreset=True)
        self.config = config
        self.registry = registry or get_default_registry()
        self.context = ActionContext()
        
        # Results tracking
        self.results: List[ActionResult] = []
    
    def execute_all(self) -> bool:
        """Execute all registered actions.
        
        Returns:
            True if all actions succeeded or were not needed, False if any failed
        """
        print("\n" + "="*60)
        print("STARTING SYSTEM INSTALLATION")
        print("="*60)
        
        success = True
        
        for action_meta in self.registry.get_all_actions():
            result = self._execute_action(action_meta)
            self.results.append(result)
            
            if result.status == 'failed':
                success = False
                # Continue with other actions even if one fails
        
        self._print_summary()
        return success
    
    def _execute_action(self, action_meta: Dict[str, Any]) -> ActionResult:
        """Execute a single action.
        
        Args:
            action_meta: Action metadata from registry
            
        Returns:
            ActionResult with execution result
        """
        action_class = action_meta['class']
        config_key = action_meta['config_key']
        
        # Get action name from class
        try:
            # Create temporary instance to get name
            temp_action = action_class({}, self.context)
            action_name = temp_action.name
        except Exception:
            action_name = action_class.__name__
        
        print(f"\n{'='*60}")
        print(f"{action_name.upper()}")
        print(f"{'='*60}")
        
        # Validate configuration
        is_valid, error_msg = self.registry.validate_config(self.config, action_meta)
        if not is_valid:
            message = error_msg or "Configuration validation failed"
            if action_meta['is_optional']:
                print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {message}{Style.RESET_ALL}")
                return ActionResult(action_name, 'skipped', message)
            else:
                print(f"{Fore.RED}❌ Cannot execute {action_name}: {message}{Style.RESET_ALL}")
                return ActionResult(action_name, 'failed', message)
        
        # Extract config for this action
        if config_key == '__root__':
            # Special case: action uses root-level config
            action_config = self.config
        else:
            action_config = self.config.get(config_key, {})
        
        try:
            # Create action instance
            action = action_class(action_config, self.context)
            
            # Check if action is needed (idempotency)
            print(f"Checking if {action_name} is needed...")
            if not action.is_needed():
                print(f"{Fore.CYAN}ℹ️  {action_name} already configured - skipping{Style.RESET_ALL}")
                return ActionResult(action_name, 'not_needed', 'Already configured')
            
            # Execute action
            print(f"Executing {action_name}...")
            action.execute()
            
            # Verify results
            if not action.verify():
                raise RuntimeError("Verification failed after execution")
            
            print(f"{Fore.GREEN}✅ {action_name} completed successfully!{Style.RESET_ALL}")
            return ActionResult(action_name, 'success')
            
        except Exception as e:
            error_msg = str(e)
            print(f"{Fore.RED}❌ Error during {action_name}: {error_msg}{Style.RESET_ALL}")
            import traceback
            traceback.print_exc()
            return ActionResult(action_name, 'failed', error_msg)
    
    def _print_summary(self) -> None:
        """Print execution summary."""
        print("\n" + "="*60)
        print("INSTALLATION SUMMARY")
        print("="*60)
        
        # Categorize results
        successful = [r for r in self.results if r.status == 'success']
        not_needed = [r for r in self.results if r.status == 'not_needed']
        skipped = [r for r in self.results if r.status == 'skipped']
        failed = [r for r in self.results if r.status == 'failed']
        
        if successful:
            print(f"\n{Fore.GREEN}✅ Successfully executed:{Style.RESET_ALL}")
            for result in successful:
                print(f"   • {result.name}")
        
        if not_needed:
            print(f"\n{Fore.CYAN}ℹ️  Already configured (idempotent):{Style.RESET_ALL}")
            for result in not_needed:
                print(f"   • {result.name}")
        
        if skipped:
            print(f"\n{Fore.YELLOW}⚠️  Skipped:{Style.RESET_ALL}")
            for result in skipped:
                print(f"   • {result.name}: {result.message}")
        
        if failed:
            print(f"\n{Fore.RED}❌ Failed:{Style.RESET_ALL}")
            for result in failed:
                print(f"   • {result.name}: {result.message}")
        
        # Overall status
        print(f"\n{'='*60}")
        if failed:
            print(f"{Fore.RED}Installation completed with errors{Style.RESET_ALL}")
        elif skipped:
            print(f"{Fore.YELLOW}Installation completed with some actions skipped{Style.RESET_ALL}")
        elif not_needed and not successful:
            print(f"{Fore.CYAN}System already configured - no changes needed{Style.RESET_ALL}")
        else:
            print(f"{Fore.GREEN}Installation completed successfully!{Style.RESET_ALL}")
        print("="*60)
    
    def get_partition(self, label: str) -> str | None:
        """Get device path for a partition label.
        
        Args:
            label: Partition label
            
        Returns:
            Device path or None
        """
        return self.context.get_partition(label)
