import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1])
APPCTL = os.environ["APPCTL_BIN"]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path not in ("/", "/summary", "/health"):
            self.send_error(404)
            return
        try:
            body = subprocess.check_output([APPCTL, "summary"], stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as exc:
            body = b'{"error":"appctl summary failed"}'
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            sys.stderr.write(exc.output.decode("utf-8", "replace"))
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
