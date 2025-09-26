from .abstract_action import AbstractAction
from colorama import Fore, Style, init
from sys import exit
from ..command_worker.command_worker import Command
from pathlib import Path

class TimezoneAction(AbstractAction):
    
    def __init__(self, prop : dict):
        init(autoreset=True)
        # Mandatory properties check
        if any(key in prop for key in ("continent", "region")):
            print(Fore.RED + "Mandatory keys do not exist for region." + Style.RESET_ALL)
            exit(1)
        
        self._KEY_NAME = "timezone"
        self._can_incrementally_change = True
        
        self.region : str = prop[self._KEY_NAME]["region"]
        self.city : str = prop[self._KEY_NAME]["city"]
        
    def _before_check(self) -> bool:
        link = Path("/mnt/etc/localtime")
        
        return not (link.is_symlink() and link.readlink().as_posix().split("/")[4] == self.region and link.readlink().as_posix().split("/")[5] == self.city)
    
    def after_check(self):
        pass
    
    def do_action(self):
        if self._before_check():
            Command.execute("ln", ["-sf", f"/usr/share/zoneinfo/{self.region}/{self.city}", "/etc/localtime"], True)
            Command.execute("hwclock", ["--systohc"], True)
        
    @property
    def KEY_NAME(self) -> str:
        return self._KEY_NAME
    
    @property
    def can_incrementally_change(self) -> bool:
        return self._can_incrementally_change        