from typing import Dict, Optional, Any
from ..json_parser.json_parser import JsonParser
from .disk_partition_action import DiskPartitionAction

class ActionsHandler:
    def __init__(self, filename: str):
        json_parser = JsonParser(filename)
        data = json_parser.debug()
        
        # Store partition mappings for use by other actions
        self.partition_map: Dict[str, str] = {}
        
        # Process disk partitioning first if configured
        if data.get('disks'):
            print("\n" + "="*60)
            print("DISK PARTITIONING")
            print("="*60)
            self._handle_disk_partitioning(data['disks'])
        
        # Other actions can be added here
        # from .base_install_action import BaseInstallAction
        # from .timezone_action import TimezoneAction
        # from .locale_action import LocaleAction
        # from .network_action import NetworkAction
        # BaseInstallAction(data).do_action()
        # TimezoneAction(data).do_action()
        # LocaleAction(data).do_action()
        # NetworkAction(data).do_action()
    
    def _handle_disk_partitioning(self, disk_config: Dict[str, Any]) -> None:
        """Handle disk partitioning action.
        
        Args:
            disk_config: Disk configuration dictionary
        """
        try:
            from ..models.disk_model import DisksConfiguration
            
            # Parse and validate configuration
            config = DisksConfiguration(**disk_config)
            
            # Create and run action
            action = DiskPartitionAction(config)
            action.do_action()
            
            # Store partition mappings for later use
            self.partition_map = action.get_all_partitions()
            
            print("\n✅ Disk partitioning completed successfully!")
            print("\nCreated partitions:")
            for label, device in self.partition_map.items():
                print(f"  {label}: {device}")
                
        except Exception as e:
            print(f"\n❌ Error during disk partitioning: {e}")
            import traceback
            traceback.print_exc()
            raise
    
    def get_partition(self, label: str) -> Optional[str]:
        """Get device path for a partition by label.
        
        Args:
            label: Partition label
            
        Returns:
            Device path or None if not found
        """
        return self.partition_map.get(label)