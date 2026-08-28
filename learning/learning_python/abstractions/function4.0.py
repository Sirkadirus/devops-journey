def monitoring_api(host, endpoint="/health", retries=3):
    codes = [500, 500, 500]
    tries = 0

    for code in codes:
        if code == 200:
            print(f"{host} {endpoint}: OK")
            return True
    
    while tries < retries:
        tries+= 1
        print(f"{host} {endpoint}: retry {tries}")
        if tries == retries:
            print(f"{host} {endpoint}: FAIL")
            return False
        
monitoring_api("http://localhost")
monitoring_api("http://localhost", "/status", 2)
        