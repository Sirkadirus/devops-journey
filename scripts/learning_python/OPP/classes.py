class Monitoring:
    def __init__(self, service):
        self.service = service
        
    def check_code_status(self, status_code):
        if status_code == 200:
            print(f"{self.service} OK")
            return True
        else:
            print(f"{self.service} FAIL")
            return False
        
    def retries(self, status_code, retries=3):
        if status_code ==200:
            print(f"{self.service} OK")
            return True
        else:
            tries = 0
            while tries < retries:
                tries+= 1 
                print(f"{self.service} retry {tries}")
                if tries == 3:
                    print(f"{self.service} FAIL")
            return False
        
monitoring_nginx = Monitoring("nginx")
monitoring_postgresql = Monitoring("postgresql")
monitoring_redis = Monitoring("redis")

monitoring_nginx.check_code_status(200)
monitoring_postgresql.retries(500)
monitoring_redis.retries(200)
        
        