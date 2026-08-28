def habitos_de_bano(funcion):
    
    def wrappers():
        print("papel para ")
        funcion()
        print("me lavo las manos")
    
    return wrappers

@habitos_de_bano
def cagar():
    print("cagar")
cagar()
