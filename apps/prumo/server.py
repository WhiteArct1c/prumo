"""Prumo sample workload.

This API exists so the delivery path has something to run. It is not a
product. A product team would put their own service here.
"""

import os
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8080"))
ENVIRONMENT = os.environ.get("ENVIRONMENT", "local")
SAFE_ENVIRONMENT = re.sub(r"[^A-Za-z0-9_-]", "_", ENVIRONMENT) or "local"
REQUESTS = {"/": 0, "/healthz": 0, "other": 0}
REQUESTS_LOCK = threading.Lock()
TRACEPARENT = re.compile(r"^[0-9a-f]{2}-([0-9a-f]{32})-[0-9a-f]{16}-[0-9a-f]{2}$")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path != "/metrics":
            key = path if path in ("/", "/healthz") else "other"
            with REQUESTS_LOCK:
                REQUESTS[key] += 1
        if path == "/healthz":
            self._send(200, "text/plain; charset=utf-8", b"ok\n")
            return
        if path == "/metrics":
            lines = [
                "# HELP prumo_up 1 while the process is serving.",
                "# TYPE prumo_up gauge",
                "prumo_up 1",
                "# HELP prumo_info Identity of the sample workload.",
                "# TYPE prumo_info gauge",
                f'prumo_info{{environment="{SAFE_ENVIRONMENT}"}} 1',
                "# HELP prumo_requests_total HTTP requests received, excluding /metrics.",
                "# TYPE prumo_requests_total counter",
            ]
            with REQUESTS_LOCK:
                snapshot = dict(REQUESTS)
            for route, count in snapshot.items():
                lines.append(
                    f'prumo_requests_total{{path="{route}",environment="{SAFE_ENVIRONMENT}"}} {count}'
                )
            body = ("\n".join(lines) + "\n").encode()
            self._send(200, "text/plain; version=0.0.4; charset=utf-8", body)
            return
        if path == "/":
            message = f"Prumo sample workload. Environment: {SAFE_ENVIRONMENT}.\n"
            self._send(200, "text/plain; charset=utf-8", message.encode())
            return
        self._send(404, "text/plain; charset=utf-8", b"not found\n")

    def _send(self, status, content_type, body):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        line = f"[{SAFE_ENVIRONMENT}] {self.address_string()} {fmt % args}"
        headers = getattr(self, "headers", None)
        match = TRACEPARENT.match(headers.get("traceparent", "")) if headers else None
        if match:
            line += f" trace_id={match.group(1)}"
        print(line)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"listening on {PORT} environment={SAFE_ENVIRONMENT}")
    server.serve_forever()
