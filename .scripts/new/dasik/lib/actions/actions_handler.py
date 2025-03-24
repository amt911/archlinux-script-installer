from ..json_parser.json_parser import JsonParser
from .base_install_action import BaseInstallAction
from .timezone_action import TimezoneAction
class ActionsHandler:
    def __init__(self, filename : str):
        json_parser = JsonParser(filename)
        example = BaseInstallAction(json_parser.debug())
        example.do_action()