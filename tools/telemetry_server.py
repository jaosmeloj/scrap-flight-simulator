"""Receives the Studio flight telemetry (LaunchService.sendTelemetry) and saves one JSON file per flight.

    python tools/telemetry_server.py      -> listens on 127.0.0.1:8770, writes tools/telemetry/flight_<time>.json
Needs "Allow HTTP Requests" on in the place (Game Settings -> Security). Only Studio sends anything.
"""

import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "telemetry")
os.makedirs(OUT, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            data = json.loads(body)
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return
        name = os.path.join(OUT, time.strftime("flight_%Y%m%d_%H%M%S.json"))
        with open(name, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1)
        print("saved", name, "distance", data.get("distance"), flush=True)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 8770), Handler).serve_forever()
