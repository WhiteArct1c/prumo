"""Workload de referência do Prumo.

Esta API existe para o caminho de entrega ter o que carregar. Ela não é um
produto. Um time de produto teria o próprio serviço neste lugar.
"""

import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8080"))
ENVIRONMENT = os.environ.get("ENVIRONMENT", "local")
SAFE_ENVIRONMENT = re.sub(r"[^A-Za-z0-9_-]", "_", ENVIRONMENT) or "local"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/healthz":
            self._send(200, "text/plain; charset=utf-8", b"ok\n")
            return
        if path == "/metrics":
            body = (
                "# HELP prumo_up 1 enquanto o processo está atendendo.\n"
                "# TYPE prumo_up gauge\n"
                "prumo_up 1\n"
                "# HELP prumo_info Identidade do workload de referência.\n"
                "# TYPE prumo_info gauge\n"
                f'prumo_info{{environment="{SAFE_ENVIRONMENT}"}} 1\n'
            ).encode()
            self._send(200, "text/plain; version=0.0.4; charset=utf-8", body)
            return
        if path == "/":
            message = f"Prumo workload de referência. Ambiente: {SAFE_ENVIRONMENT}.\n"
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
        print(f"[{SAFE_ENVIRONMENT}] {self.address_string()} {fmt % args}")


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"listening on {PORT} environment={SAFE_ENVIRONMENT}")
    server.serve_forever()
