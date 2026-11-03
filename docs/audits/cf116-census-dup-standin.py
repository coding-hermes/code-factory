#!/usr/bin/env python3
"""Stand-in scheduler that reproduces the page-drift hole in the census recipe's
coverage assertion (CF-089): a run can receive exactly `total` rows and still
never see one of them.

Page offset=0 serves rows 0..499 of a 600-row list. Before the second fetch one
project is inserted at the head of the scheduler's list, so every later offset
shifts by one: page offset=500 serves row 499 a second time and never serves row
500. Rows received = 500 + 100 = 600 == total 600, so a census that only counts
rows prints a plausible, complete-looking output.

Truth served here: 600 reported rows, 599 distinct, row 500 never served, row
499 served twice.
"""

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

TOTAL = 600
PAGE = 500


def row(i):
    return {
        "name": "code-factory-p%03d" % i,
        "enabled": True,
        "admission_mode": "cooldown",
        "parent": "code-factory",
    }


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        if not u.path.startswith("/api/v1/projects"):
            self.send_response(404)
            self.end_headers()
            return
        q = parse_qs(u.query)
        limit = int(q.get("limit", [str(PAGE)])[0])
        offset = int(q.get("offset", ["0"])[0])
        if offset == 0:
            rows = [row(i) for i in range(0, PAGE)]
        else:
            # The list shifted by one between the fetches: one duplicate, one hole.
            rows = [row(PAGE - 1)] + [row(i) for i in range(PAGE + 1, TOTAL)]
        self.reply({"total": TOTAL, "limit": limit, "offset": offset, "projects": rows})


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--port", type=int, default=18996)
args = parser.parse_args()
HTTPServer(("127.0.0.1", args.port), H).serve_forever()
