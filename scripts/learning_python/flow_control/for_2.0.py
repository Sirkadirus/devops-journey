ports = [80, 443, 8080, 3000]

for port in ports:
    if port == 80 or port == 443:
        print(f"Port {port} well-known port")
    else:
        print(f"Port {port} registered port")
        