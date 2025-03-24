from .abstract_action import AbstractAction
from termcolor import colored
from sys import exit
from ..command_worker.command_worker import Command

class TimezoneAction(AbstractAction):
    
    def __init__(self, prop : dict):
        # Mandatory properties check
        if any(key in prop for key in ("continent", "region")):
            print(colored("Mandatory keys do not exist for region.", "red"))
            exit(1)
        
        self._KEY_NAME = "timezone"
        self._can_incrementally_change = True
        
        self.region : str = prop["region"]
        self.city : str = prop["city"]
        
    def before_check(self):
        pass
    
    def after_check(self):
        pass
    
    def do_action(self):
        Command.execute("ln", ["-sf", f"/usr/share/zoneinfo/{self.region}/{self.city}"])
        
    @property
    def KEY_NAME(self) -> str:
        return self._KEY_NAME
    
    @property
    def can_incrementally_change(self) -> bool:
        return self._can_incrementally_change        