services = ["nginx", "postgresql", "redis"]
check_codes = [200, 500, 200]

for service, code in zip(services, check_codes):
    tries = 0
    while tries < 2:
        if service != "postgresql":
            print(f"{service} {code} OK")
            break
        
        elif service == "postgresql":
            tries += 1
            print(f"try {tries}")
            if tries == 2:
               print(f"{service} {code} FAIL")
               break
            
            
            
    