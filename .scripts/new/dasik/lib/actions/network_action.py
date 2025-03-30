from .abstract_action import AbstractAction
from ..command_worker.command_worker import Command
from ..exceptions.exceptions import NetworkTypeNotFoundException
import re
class NetworkAction(AbstractAction):
    def __init__(self, prop : dict):
        self._KEY_NAME = "network"
        self._can_incrementally_change = True
        
        self.type = prop[self._KEY_NAME]["type"]
        self.hostname = prop["hostname"]
        self.add_default_hosts = prop[self._KEY_NAME]["add_default_hosts"]
        self.DEFAULT_HOSTS = ("127.0.0.1 localhost\n"
                              "::1 localhost\n"
                              f"127.0.1.1 {self.hostname}\n")
        
    def _before_check(self) -> bool:
        return super()._before_check()
        
        
    def after_check(self):
        return super().after_check()
    
    
    def _install_network_manager(self):
        pass
    
    
    def _install_systemd_networkd(self):
        pass
    
    
    def _create_hostname_file(self):
        with open("/mnt/etc/hostname", "w") as hostname:
            hostname.write(self.hostname)
    
    
    def _add_default_hosts_to_file(self):
        with open("/mnt/etc/hosts", "a") as hosts_file:
            hosts_file.write(self.DEFAULT_HOSTS)
    
    # Returns true when a change in the hosts file is needed, false in any other case
    def _check_hosts_file(self) -> bool:
        with open("/mnt/etc/hosts", "r") as hosts_file:
            hosts_file_str = hosts_file.read()
            
            return re.search(rf"^{re.escape(self.DEFAULT_HOSTS)}", hosts_file_str, re.MULTILINE) is None
        
        return True
    
    
    def do_action(self):
        if self._before_check():
            print(self._check_hosts_file())
            '''
            self._create_hostname_file()
            self._add_default_hosts_to_file()
            
            match self.type:
                case "NetworkManager":
                    self._install_network_manager()
                    
                case "systemd-networkd":
                    self._install_systemd_networkd()
                    
                case _:
                    raise NetworkTypeNotFoundException
            '''
    @property
    def KEY_NAME(self) -> str:
        return self._KEY_NAME
    
    @property
    def can_incrementally_change(self) -> bool:
        return self._can_incrementally_change            