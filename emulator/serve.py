import http.server
import os


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
print("http://localhost:8765/emulator/")
http.server.ThreadingHTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
