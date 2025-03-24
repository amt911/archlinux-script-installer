from sys import argv
from lib.json_parser.json_parser import JsonParser
from lib.command_worker.command_worker import Command

from lib.actions.base_install_action import BaseInstallAction
from lib.actions.actions_handler import ActionsHandler

a = JsonParser(argv[1])

# print(type(a.debug()["locales"]["selected_locales"]))
# print(type(a.get_attr("bootloader")))

# b = Command()

# print(Command.locate_binary("echo"))

# print(Command.execute("echo", ["hola que tal"]).stdout)

b = ActionsHandler(argv[1])