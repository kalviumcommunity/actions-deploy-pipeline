import importlib.util
import threading
import unittest
import urllib.request
import json
from http.server import ThreadingHTTPServer

spec = importlib.util.spec_from_file_location("app", "app/app.py")
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)

class HealthTest(unittest.TestCase):
    def test_health(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), app.Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{server.server_port}/health") as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(json.load(response)["status"], "ok")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

if __name__ == "__main__":
    unittest.main()
