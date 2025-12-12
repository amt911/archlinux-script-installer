from typing import Dict, Any, Optional

class ActionContext:
    """Shared context between actions during installation.
    
    This allows actions to share state and communicate with each other.
    For example, disk partitioning action can store partition mappings
    that will be used by the base installation action.
    """
    
    def __init__(self):
        """Initialize empty context."""
        self._data: Dict[str, Any] = {}
        self.partition_map: Dict[str, str] = {}
    
    def set(self, key: str, value: Any) -> None:
        """Store a value in the context.
        
        Args:
            key: Context key
            value: Value to store
        """
        self._data[key] = value
    
    def get(self, key: str, default: Any = None) -> Any:
        """Retrieve a value from the context.
        
        Args:
            key: Context key
            default: Default value if key not found
            
        Returns:
            Stored value or default
        """
        return self._data.get(key, default)
    
    def has(self, key: str) -> bool:
        """Check if a key exists in the context.
        
        Args:
            key: Context key to check
            
        Returns:
            True if key exists
        """
        return key in self._data
    
    def set_partition(self, label: str, device: str) -> None:
        """Store a partition mapping.
        
        Args:
            label: Partition label (e.g., 'root', 'boot')
            device: Device path (e.g., '/dev/sda1')
        """
        self.partition_map[label] = device
    
    def get_partition(self, label: str) -> Optional[str]:
        """Get device path for a partition label.
        
        Args:
            label: Partition label
            
        Returns:
            Device path or None if not found
        """
        return self.partition_map.get(label)
    
    def get_all_partitions(self) -> Dict[str, str]:
        """Get all partition mappings.
        
        Returns:
            Dictionary of label -> device mappings
        """
        return self.partition_map.copy()
