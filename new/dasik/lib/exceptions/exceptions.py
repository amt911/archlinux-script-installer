

class CommandNotFoundException(Exception):
    def __init__(self, message : str = "Requested command not found"):
        super().__init__(message)

class NetworkTypeNotFoundException(Exception):
    def __init__(self, message : str = "Network type not recognized."):
        super().__init__(message)
        
class CommandExecutionError(Exception):
    def __init__(self, message : str = "Error executing command."):
        super().__init__(message)