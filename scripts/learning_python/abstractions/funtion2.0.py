def check_service(name,code):
    if code == 200:
        print(f"{name} OK")
        return True
    else:
        print(f"{name} FAIL")
        return False

services = ["nginx", "postgresql", "redis"] 
codes = [200, 200, 200]

for server, code in zip(services, codes):
    check_service(server,code)
    