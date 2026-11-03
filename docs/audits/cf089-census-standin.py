#!/usr/bin/env python3
"""Stand-in scheduler /api/v1/projects used to exercise the README census recipe's
per-page failure path. Serves 866 rows; page offset=500 answers HTTP 502 like a
restarting scheduler. Truth: exactly TWO code-factory rows exist (index 0 and 600).
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

TOTAL = 866

def row(i):
    name = "code-factory" if i in (0, 600) else "proj-%04d" % i
    return {"name": name, "enabled": True, "admission_mode": "cooldown", "parent": "x"}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path.startswith("/nototal"):
            body = json.dumps({"projects": []}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if not u.path.startswith("/api/v1/projects"):
            self.send_response(404)
            self.end_headers()
            return
        limit = int(q.get("limit", ["200"])[0])
        offset = int(q.get("offset", ["0"])[0])
        if offset >= 500:
            body = json.dumps({"error": "upstream timeout"}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        n = min(limit, 500, TOTAL - offset)
        body = json.dumps({"total": TOTAL, "limit": limit, "offset": offset,
                           "projects": [row(i) for i in range(offset, offset + n)]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

HTTPServer(("127.0.0.1", 18999), H).serve_forever()
