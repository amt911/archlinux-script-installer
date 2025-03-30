from abc import ABC, abstractmethod

class AbstractAction(ABC):
    # Returns True if there are changes to be made
    @abstractmethod
    def _before_check(self) -> bool:
        return True
    
    @abstractmethod
    def after_check(self):
        pass
    
    @abstractmethod
    def do_action(self):
        pass
    
    @property
    @abstractmethod
    def can_incrementally_change(self) -> bool:
        pass
    
    @property
    @abstractmethod
    def KEY_NAME(self) -> str:
        pass