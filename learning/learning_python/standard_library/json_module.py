import json

response_json = '{"status": "healthy", "version": "0.1.1"}'
dict_convert = json.loads(response_json)

if (dict_convert["status"]) == "healthy":
    print("API operative")
else:
    print("API degrade")