from ..json_parser.json_parser import JsonParser
from .base_install_action import BaseInstallAction
from .timezone_action import TimezoneAction
class ActionsHandler:
    def __init__(self, filename : str):
        json_parser = JsonParser(filename)
        BaseInstallAction(json_parser.debug()).do_action()
        TimezoneAction(json_parser.debug()).do_action()