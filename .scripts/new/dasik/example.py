import json

example = open("../config/system-config.json")
a = json.load(example)

print(example.read())
print(a["users"][0]["user"])

example.close()