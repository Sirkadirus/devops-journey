server_conection = False
tries = 0

while True:
    tries += 1
    print(f"Try {tries}")
    if tries == 4:
        print("Timeout")
        break
    if tries == 25:
        server_conection = True
        print("Conected")
        break
    
        