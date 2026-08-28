try:
    file = open("config.txt")
except FileNotFoundError:
    print("File does not exist, shows default value")
else:
    content = file.read()
    print(content)
    file.close()
    print("File readed correctly")
finally:
    print("Operation Concluded")
