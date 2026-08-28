from learning.learning_python.modularity import db
from learning.learning_python.modularity import monitoring

services = ["nginx", "postgresql"]
codes = [200, 500]

for service, code in zip(services, codes):
    if monitoring.check_service(service, code):
        print(f"{service} OK")
    else:
        print(f"{service} FAIL")
        
print(db.connect())
