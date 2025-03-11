from abstract_action import AbstractAction
from termcolor import colored
from sys import exit


class RegionAction(AbstractAction):
    
    def __init__(self, prop : dict):
        # Mandatory properties check
        if any(key in prop for key in ("continent", "region")):
            print(colored("Mandatory keys do not exist for region.", "red"))
            exit(1)
        
        self._KEY_NAME = "region"
        self._can_incrementally_change = True
        
        # self.continent : str = prop["continent"]
        # self.region : str = prop["region"]