from sys import argv
from dasik.lib.json_parser.json_parser import JsonParser
from dasik.lib.command_worker.command_worker import Command

from dasik.lib.actions.base_install_action import BaseInstallAction
from dasik.lib.actions.actions_handler import ActionsHandler


def main():
    """Main entry point for the dasik application."""
    if len(argv) < 2:
        print("Usage: dasik <config-file.json>")
        return 1
    
    a = JsonParser(argv[1])

    # print(type(a.debug()["locales"]["selected_locales"]))
    # print(type(a.get_attr("bootloader")))

    # b = Command()

    # print(Command.locate_binary("echo"))

    # print(Command.execute("echo", ["hola que tal"]).stdout)

    b = ActionsHandler(argv[1])
    return 0


if __name__ == "__main__":
    exit(main())