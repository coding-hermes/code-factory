import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "add_family_lanes.py"
LANE_NAMES = [
    "code-factory-docs",
    "code-factory-docs-qa",
    "code-factory-readme",
    "code-factory-readme-qa",
    "code-factory-releng",
    "code-factory-releng-qa",
    "code-factory-perf",
    "code-factory-review",
]


class LaneStub(BaseHTTPRequestHandler):
    state = None

    def log_message(self, *_args):
        pass

    def _body(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        return json.loads(raw) if raw else None

    def _reply(self, status, body=None):
        raw = json.dumps(body or {}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _handle(self):
        body = self._body() if self.command in {"POST", "PUT", "PATCH"} else None
        self.state["requests"].append((self.command, self.path, body))
        name = self.path.rsplit("/", 1)[-1]
        if self.command == "GET":
            if name in self.state["present"]:
                self._reply(200, {"project": self.state["present"][name]})
            else:
                self._reply(404)
            return
        if self.command == "POST":
            if self.state["create_refused"]:
                self._reply(self.state["create_refused"])
            else:
                project = {
                    "name": body["name"],
                    "namespace_id": body.get("namespace_id"),
                    "model": "",
                    "provider": "",
                }
                self.state["present"][body["name"]] = project
                self._reply(201, {"project": project})
            return
        if self.command == "PUT":
            if self.state["put_refused"]:
                self._reply(self.state["put_refused"])
            else:
                self.state["present"].setdefault(name, {"name": name}).update(body)
                self._reply(200, self.state["present"][name])
            return
        self._reply(405)

    do_GET = _handle
    do_POST = _handle
    do_PUT = _handle


def run_case(*, present=None, create_refused=0, put_refused=0):
    state = {
        "present": dict(present or {}),
        "create_refused": create_refused,
        "put_refused": put_refused,
        "requests": [],
    }
    LaneStub.state = state
    server = ThreadingHTTPServer(("127.0.0.1", 0), LaneStub)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    home = Path(tempfile.mkdtemp(prefix="cf-321-home-"))
    try:
        env = dict(os.environ, CODER_API_TOKEN="stub-token", HOME=str(home))
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--api-base", f"http://127.0.0.1:{server.server_port}"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        return result, state["requests"]
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
        shutil.rmtree(home)


def complete_project(name, namespace):
    prompt_name = "qa" if name.endswith("-qa") else name.removeprefix("code-factory-")
    return {
        "name": name,
        "namespace_id": namespace,
        "prompt": (ROOT / "prompts" / f"{prompt_name}.md").read_text(),
        "prompt_mode": "append",
        "parent": "code-factory",
        "admission_mode": "cooldown",
        "model": "",
        "provider": "",
    }


def test_all_creations_refused_exit_nonzero_and_counts_refusals():
    result, requests = run_case(create_refused=400)
    assert result.returncode == 2
    assert "summary created=0 present=0 refused=8" in result.stdout
    assert sum(method == "POST" for method, _, _ in requests) == 8


def test_partial_refusal_exit_nonzero():
    present = {LANE_NAMES[0]: complete_project(LANE_NAMES[0], "docs")}
    result, _ = run_case(present=present, create_refused=400)
    assert result.returncode == 2
    assert "summary created=0 present=1 refused=7" in result.stdout


def test_all_already_present_makes_no_mutating_requests():
    namespaces = {
        "code-factory-docs": "docs",
        "code-factory-docs-qa": "qa",
        "code-factory-readme": "docs",
        "code-factory-readme-qa": "qa",
        "code-factory-releng": "releases",
        "code-factory-releng-qa": "qa",
        "code-factory-perf": "perf",
        "code-factory-review": "review",
    }
    present = {name: complete_project(name, namespaces[name]) for name in LANE_NAMES}
    result, requests = run_case(present=present)
    assert result.returncode == 0
    assert "summary created=0 present=8 refused=0" in result.stdout
    assert all(method not in {"POST", "PUT"} for method, _, _ in requests)


def test_phase_two_put_refusal_is_nonzero():
    result, requests = run_case(put_refused=403)
    assert result.returncode == 2
    assert "summary created=8 present=0 refused=8" in result.stdout
    assert sum(method == "PUT" for method, _, _ in requests) == 8


def test_phase_two_is_api_only():
    source = (ROOT / "scripts" / "add_family_lanes.py").read_text()
    assert "import sqlite3" not in source
    assert "scheduler.db" not in source
