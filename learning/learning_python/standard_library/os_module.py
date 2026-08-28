import os

print(os.getcwd())
print(os.listdir("/home/j"))

api_key = os.getenv("API_KEY")

if api_key != None:
    print(api_key)
else:
    print("API_KEY not defined")