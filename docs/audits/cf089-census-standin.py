#!/usr/bin/env python3
"""Stand-in scheduler /api/v1/projects used to exercise the README census recipe's
per-page failure path. Serves 866 rows; page offset=500 answers HTTP 502 like a
restarting scheduler. Truth: exactly TWO code-factory rows exist (index 0 and 600).
"""

import argparse
import json
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

TOTAL = 866


def row(i):
    name = "code-factory" if i in (0, 600) else "proj-%04d" % i
    return {"name": name, "enabled": True, "admission_mode": "cooldown", "parent": "x"}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, status, payload):
        body = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path.startswith("/nototal") or args.mode == "nototal":
            self.reply(200, {"projects": []})
            return
        if not u.path.startswith("/api/v1/projects"):
            self.send_response(404)
            self.end_headers()
            return
        limit = int(q.get("limit", ["200"])[0])
        offset = int(q.get("offset", ["0"])[0])
        if offset >= 500:
            if args.mode == "broken":
                self.reply(502, {"error": "upstream timeout"})
                return
            if args.mode == "fetch":
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                return
            if args.mode == "missing-projects":
                self.reply(200, {"total": TOTAL})
                return
            if args.mode == "wrong-projects":
                self.reply(200, {"total": TOTAL, "projects": {}})
                return
            if args.mode == "nonjson":
                self.reply(200, b"scheduler restarting")
                return
        n = min(limit, 500, TOTAL - offset)
        if offset >= 500 and args.mode == "short":
            n -= 1
        self.reply(
            200,
            {
                "total": TOTAL,
                "limit": limit,
                "offset": offset,
                "projects": [row(i) for i in range(offset, offset + n)],
            },
        )


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--port", type=int, default=18999)
parser.add_argument(
    "--mode",
    choices=(
        "broken",
        "fetch",
        "missing-projects",
        "wrong-projects",
        "nonjson",
        "short",
        "healthy",
        "nototal",
    ),
    default="broken",
)
args = parser.parse_args()
HTTPServer(("127.0.0.1", args.port), H).serve_forever()
