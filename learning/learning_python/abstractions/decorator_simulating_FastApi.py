class FastAPI:

    def __init__(self):
        self.routes = []

    def get(self, path):

        def decorator(func):

            self.routes.append({
                "method": "GET",
                "path": path,
                "handler": func
            })

            return func

        return decorator