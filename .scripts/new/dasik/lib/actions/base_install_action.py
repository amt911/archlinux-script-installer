from .abstract_action import AbstractAction
from ..command_worker.command_worker import Command
from termcolor import colored

# !!! TODO: Check for already installed packages
class BaseInstallAction(AbstractAction):
    def __init__(self, prop : dict):
        self.packages = [ "base", "linux", "linux-firmware" ]
        self.enable_microcode = prop["enable_microcode"]
        
        # !!! ALSO CHECK FOR BTRFS
        self._KEY_NAME = "no_name"
        self._can_incrementally_change = True
        
        if self.enable_microcode:
            with open("/proc/cpuinfo", "r") as cpuinfo:
                content = cpuinfo.read()
                
                if "AuthenticAMD" in content:
                    self.packages += [ "amd-ucode" ]
                elif "GenuineIntel" in content:
                    self.packages += [ "intel-ucode" ]
                else:
                    print(colored("Unknown CPU Vendor. Exiting...", "red"))
                    exit(1)
        
    @property
    def KEY_NAME(self) -> str:
        return self._KEY_NAME
    
    @property
    def can_incrementally_change(self) -> bool:
        return self._can_incrementally_change
    
    def _before_check(self) -> bool:
        return True
    
    def after_check(self):
        pass
    
    def do_action(self):
        Command.execute("pacman", ["--noconfirm", "-Sy", "archlinux-keyring"])
        Command.execute("pacstrap", ["-K", "/mnt"] + self.packages)
        fstab_content_str = Command.execute("genfstab", ["-U", "/mnt"]).stdout.decode()
        
        with open("/mnt/etc/fstab", "a") as fstab:
            fstab.write(fstab_content_str)