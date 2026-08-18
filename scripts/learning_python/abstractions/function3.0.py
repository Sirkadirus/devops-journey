def verify_with_retries(name, code):
    if code == 200:
        print(f"{name} OK")
        return
    elif code != 200:
        tries = 0
        while tries < 3 :
            tries += 1 
            print(f"{name} retry {tries}")
            if tries == 3:
                print(f"{name} FAIL" )
        

services = ["nginx", "postgresql", "redis"]
codes = [200, 500, 200] 

for service, code in  zip(services, codes):
    verify_with_retries(service, code)           
    