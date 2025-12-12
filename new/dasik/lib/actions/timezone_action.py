from typing import Dict, Any
from .abstract_action import AbstractAction
from ..command_worker.command_worker import Command
from pathlib import Path


class TimezoneAction(AbstractAction):
    """Configure system timezone."""
    
    def __init__(self, config: Dict[str, Any], context=None):
        """Initialize timezone action.
        
        Args:
            config: Timezone configuration dict with 'region' and 'city'
            context: Shared action context (unused by this action)
        """
        super().__init__(config, context)
        self.region: str = config["region"]
        self.city: str = config["city"]
    
    @property
    def name(self) -> str:
        """Return action name."""
        return "Timezone Configuration"
    
    def is_needed(self) -> bool:
        """Check if timezone needs to be configured.
        
        Returns:
            True if current timezone differs from desired configuration
        """
        link = Path("/mnt/etc/localtime")
        
        # Check if symlink exists and points to correct timezone
        if not link.exists():
            return True
        
        if not link.is_symlink():
            return True
        
        try:
            target = link.readlink()
            parts = target.as_posix().split("/")
            
            # Expected format: /usr/share/zoneinfo/Region/City
            if len(parts) < 6:
                return True
            
            current_region = parts[4]
            current_city = parts[5]
            
            return current_region != self.region or current_city != self.city
        except Exception:
            # If we can't read the link, assume we need to set it
            return True
    
    def execute(self) -> None:
        """Configure the timezone."""
        print(f"Setting timezone to {self.region}/{self.city}...")
        Command.execute("ln", ["-sf", f"/usr/share/zoneinfo/{self.region}/{self.city}", "/etc/localtime"], True)
        Command.execute("hwclock", ["--systohc"], True)
    
    def verify(self) -> bool:
        """Verify timezone was set correctly.
        
        Returns:
            True if timezone is correctly configured
        """
        link = Path("/mnt/etc/localtime")
        
        if not link.is_symlink():
            return False
        
        try:
            target = link.readlink()
            parts = target.as_posix().split("/")
            return len(parts) >= 6 and parts[4] == self.region and parts[5] == self.city
        except Exception:
            return False        