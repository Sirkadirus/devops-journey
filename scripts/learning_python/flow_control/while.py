intentos = 0
api_lista = False   

while intentos < 5 and not api_lista:
    respuesta = 200
    if respuesta == 200:
        api_lista = True                      
        print("API lista")
    else:
        intentos+= 1
        print(f"Esperando... intento {intentos}")