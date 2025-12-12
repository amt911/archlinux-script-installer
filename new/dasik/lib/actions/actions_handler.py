from typing import Dict, Optional, Any, List
from ..json_parser.json_parser import JsonParser
from .disk_partition_action import DiskPartitionAction
from colorama import Fore, Style, init

class ActionsHandler:
    def __init__(self, filename: str):
        init(autoreset=True)
        json_parser = JsonParser(filename)
        data = json_parser.debug()
        
        # Store partition mappings for use by other actions
        self.partition_map: Dict[str, str] = {}
        
        # Track executed and failed actions
        self.executed_actions: List[str] = []
        self.failed_actions: List[tuple[str, str]] = []  # (action_name, reason)
        self.skipped_actions: List[tuple[str, str]] = []  # (action_name, reason)
        
        print("\n" + "="*60)
        print("STARTING SYSTEM INSTALLATION")
        print("="*60)
        
        # Process disk partitioning first if configured
        if data.get('disks'):
            self._handle_disk_partitioning(data['disks'])
        
        # Process base installation
        self._handle_base_install(data)
        
        # Process timezone configuration
        self._handle_timezone(data)
        
        # Process locale configuration
        self._handle_locale(data)
        
        # Process network configuration
        self._handle_network(data)
        
        # Print summary
        self._print_summary()
    
    def _handle_disk_partitioning(self, disk_config: Dict[str, Any]) -> None:
        """Handle disk partitioning action.
        
        Args:
            disk_config: Disk configuration dictionary
        """
        action_name = "Disk Partitioning"
        print(f"\n{'='*60}")
        print(f"{action_name.upper()}")
        print(f"{'='*60}")
        
        try:
            from ..models.disk_model import DisksConfiguration
            
            # Parse and validate configuration
            config = DisksConfiguration(**disk_config)
            
            # Create and run action
            action = DiskPartitionAction(config)
            action.do_action()
            
            # Store partition mappings for later use
            self.partition_map = action.get_all_partitions()
            
            print(f"\n{Fore.GREEN}✅ {action_name} completed successfully!{Style.RESET_ALL}")
            print("\nCreated partitions:")
            for label, device in self.partition_map.items():
                print(f"  {label}: {device}")
            
            self.executed_actions.append(action_name)
                
        except Exception as e:
            error_msg = str(e)
            print(f"\n{Fore.RED}❌ Error during {action_name}: {error_msg}{Style.RESET_ALL}")
            import traceback
            traceback.print_exc()
            self.failed_actions.append((action_name, error_msg))
            raise
    
    def _handle_base_install(self, data: Dict[str, Any]) -> None:
        """Handle base system installation action.
        
        Args:
            data: Full configuration data
        """
        action_name = "Base Installation"
        print(f"\n{'='*60}")
        print(f"{action_name.upper()}")
        print(f"{'='*60}")
        
        # Check required fields
        required_fields = ['enable_microcode']
        missing_fields = [field for field in required_fields if field not in data]
        
        if missing_fields:
            reason = f"Missing required fields: {', '.join(missing_fields)}"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        try:
            from .base_install_action import BaseInstallAction
            
            action = BaseInstallAction(data)
            action.do_action()
            
            print(f"\n{Fore.GREEN}✅ {action_name} completed successfully!{Style.RESET_ALL}")
            self.executed_actions.append(action_name)
            
        except KeyError as e:
            reason = f"Missing configuration key: {e}"
            print(f"\n{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            
        except Exception as e:
            error_msg = str(e)
            print(f"\n{Fore.RED}❌ Error during {action_name}: {error_msg}{Style.RESET_ALL}")
            import traceback
            traceback.print_exc()
            self.failed_actions.append((action_name, error_msg))
    
    def _handle_timezone(self, data: Dict[str, Any]) -> None:
        """Handle timezone configuration action.
        
        Args:
            data: Full configuration data
        """
        action_name = "Timezone Configuration"
        print(f"\n{'='*60}")
        print(f"{action_name.upper()}")
        print(f"{'='*60}")
        
        # Check if timezone configuration exists
        if 'timezone' not in data:
            reason = "No timezone configuration found in JSON"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        # Check required fields
        timezone_data = data['timezone']
        required_fields = ['region', 'city']
        missing_fields = [field for field in required_fields if field not in timezone_data]
        
        if missing_fields:
            reason = f"Missing required fields in timezone: {', '.join(missing_fields)}"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        try:
            from .timezone_action import TimezoneAction
            
            action = TimezoneAction(data)
            action.do_action()
            
            print(f"\n{Fore.GREEN}✅ {action_name} completed successfully!{Style.RESET_ALL}")
            self.executed_actions.append(action_name)
            
        except Exception as e:
            error_msg = str(e)
            print(f"\n{Fore.RED}❌ Error during {action_name}: {error_msg}{Style.RESET_ALL}")
            import traceback
            traceback.print_exc()
            self.failed_actions.append((action_name, error_msg))
    
    def _handle_locale(self, data: Dict[str, Any]) -> None:
        """Handle locale configuration action.
        
        Args:
            data: Full configuration data
        """
        action_name = "Locale Configuration"
        print(f"\n{'='*60}")
        print(f"{action_name.upper()}")
        print(f"{'='*60}")
        
        # Check if locale configuration exists
        if 'locales' not in data:
            reason = "No locale configuration found in JSON"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        # Check required fields
        locale_data = data['locales']
        required_fields = ['selected_locales', 'desired_locale', 'desired_tty_layout']
        missing_fields = [field for field in required_fields if field not in locale_data]
        
        if missing_fields:
            reason = f"Missing required fields in locales: {', '.join(missing_fields)}"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        try:
            from .locale_action import LocaleAction
            
            action = LocaleAction(data)
            action.do_action()
            
            print(f"\n{Fore.GREEN}✅ {action_name} completed successfully!{Style.RESET_ALL}")
            self.executed_actions.append(action_name)
            
        except Exception as e:
            error_msg = str(e)
            print(f"\n{Fore.RED}❌ Error during {action_name}: {error_msg}{Style.RESET_ALL}")
            import traceback
            traceback.print_exc()
            self.failed_actions.append((action_name, error_msg))
    
    def _handle_network(self, data: Dict[str, Any]) -> None:
        """Handle network configuration action.
        
        Args:
            data: Full configuration data
        """
        action_name = "Network Configuration"
        print(f"\n{'='*60}")
        print(f"{action_name.upper()}")
        print(f"{'='*60}")
        
        # Check if network configuration exists
        if 'network' not in data:
            reason = "No network configuration found in JSON"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        # Check required fields
        network_data = data['network']
        required_fields = ['type', 'add_default_hosts']
        missing_fields = [field for field in required_fields if field not in network_data]
        
        # Also check hostname at root level
        if 'hostname' not in data:
            missing_fields.append('hostname')
        
        if missing_fields:
            reason = f"Missing required fields: {', '.join(missing_fields)}"
            print(f"{Fore.YELLOW}⚠️  Skipping {action_name}: {reason}{Style.RESET_ALL}")
            self.skipped_actions.append((action_name, reason))
            return
        
        try:
            from .network_action import NetworkAction
            
            action = NetworkAction(data)
            action.do_action()
            
            print(f"\n{Fore.GREEN}✅ {action_name} completed successfully!{Style.RESET_ALL}")
            self.executed_actions.append(action_name)
            
        except Exception as e:
            error_msg = str(e)
            print(f"\n{Fore.RED}❌ Error during {action_name}: {error_msg}{Style.RESET_ALL}")
            import traceback
            traceback.print_exc()
            self.failed_actions.append((action_name, error_msg))
    
    def _print_summary(self) -> None:
        """Print a summary of all actions."""
        print("\n" + "="*60)
        print("INSTALLATION SUMMARY")
        print("="*60)
        
        if self.executed_actions:
            print(f"\n{Fore.GREEN}✅ Successfully executed actions:{Style.RESET_ALL}")
            for action in self.executed_actions:
                print(f"   • {action}")
        
        if self.skipped_actions:
            print(f"\n{Fore.YELLOW}⚠️  Skipped actions:{Style.RESET_ALL}")
            for action, reason in self.skipped_actions:
                print(f"   • {action}: {reason}")
        
        if self.failed_actions:
            print(f"\n{Fore.RED}❌ Failed actions:{Style.RESET_ALL}")
            for action, reason in self.failed_actions:
                print(f"   • {action}: {reason}")
        
        # Overall status
        print(f"\n{'='*60}")
        if self.failed_actions:
            print(f"{Fore.RED}Installation completed with errors{Style.RESET_ALL}")
        elif self.skipped_actions:
            print(f"{Fore.YELLOW}Installation completed with some actions skipped{Style.RESET_ALL}")
        else:
            print(f"{Fore.GREEN}Installation completed successfully!{Style.RESET_ALL}")
        print("="*60)
    
    def get_partition(self, label: str) -> Optional[str]:
        """Get device path for a partition by label.
        
        Args:
            label: Partition label
            
        Returns:
            Device path or None if not found
        """
        return self.partition_map.get(label)