
from ..exceptions.exceptions import CommandNotFoundException
from shutil import which
from os import execv
import subprocess

class Command:
    
    def __init__(self):
        pass
    
    @staticmethod
    def _locate_binary(name : str) -> str:
        path = which(name)
        
        if not path:
            raise CommandNotFoundException("Binary not found")
        
        return path
    
    @staticmethod 
    def execute(cmd : str, args : list[str], run_as_chroot : bool = False):
        chroot_path = Command._locate_binary("arch-chroot")
        path = Command._locate_binary(cmd)
        
        chroot_cmd = []
        
        if run_as_chroot:
            chroot_cmd = [chroot_path, "/mnt"]    
        
        return subprocess.run(chroot_cmd + [cmd, *args], stdout=subprocess.PIPE)
        
        # execv(path, [args])
        