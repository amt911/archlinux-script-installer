from sys import argv
from lib.json_parser.json_parser import JsonParser



a = JsonParser(argv[1])

print(type(a.debug()["locales"]["selected_locales"]))
print(type(a.get_attr("bootloader")))