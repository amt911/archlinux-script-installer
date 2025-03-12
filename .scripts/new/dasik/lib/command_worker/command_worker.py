
from ..exceptions.exceptions import CommandException
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
            raise CommandException("Binary not found")
        
        return path
    
    @staticmethod 
    def execute(cmd : str, args : list[str]):
        path = Command._locate_binary(cmd)
        
        return subprocess.run([cmd, *args], stdout=subprocess.PIPE)
        
        # execv(path, [args])
        