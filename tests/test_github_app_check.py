#!/usr/bin/env python3
"""Hermetic CF-319 checks for GitHub App repository-read reporting."""

from __future__ import annotations

import http.server
import json
import os
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN_SCRIPT = ROOT / "scripts" / "github-app-token.py"
AUDIT = ROOT / "docs" / "audits" / "code-factory-CF-319-fix-2026-11-13.md"
REPO = "fixture-owner/fixture-repo"


def transcript(outputs: list[tuple[str, int, str]]) -> str:
    lines = [
        "# CF-319 fixture transcript",
        "",
        "All arms used a local HTTP stub through `--api-base`; no network or real credentials were used.",
        "",
    ]
    for label, code, output in outputs:
        lines.extend(["## %s" % label, "", "```text", output.rstrip(), "EXIT=%d" % code, "```", ""])
    return "\n".join(lines)


def assert_transcript_matches_fixture(outputs: list[tuple[str, int, str]]) -> None:
    expected = AUDIT
    # The generated transcript may contain an unpredictable TemporaryDirectory path;
    # normalize only the path portion of the private-key measurement before comparison.
    normalized_lines = []
    for line in transcript(outputs).splitlines():
        if "PASS  private_key_file — " in line:
            prefix, suffix = line.split(" — ", 1)
            suffix = suffix[suffix.index(", mode 600"):]
            line = prefix + " — <scratch>/cf-319/github-app.pem" + suffix
        normalized_lines.append(line)
    normalized = "\n".join(normalized_lines) + "\n"
    committed = expected.read_text(encoding="utf-8")
    if any(path in committed for path in ("/home/", "/var/tmp/")):
        raise AssertionError("committed CF-319 fixture contains an absolute host path")
    if normalized != committed:
        raise AssertionError(
            "generated CF-319 transcript differs from committed fixture:\n"
            + "\n".join(
                "- " + line for line in committed.splitlines() if line not in normalized.splitlines()
            )
        )


class GitHubStub(http.server.BaseHTTPRequestHandler):
    repo_status = 200
    requests: list[str] = []

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def do_POST(self) -> None:  # noqa: N802
        self.__class__.requests.append("POST " + self.path)
        if self.path != "/app/installations/123/access_tokens":
            self.send_error(404)
            return
        self._json(
            201,
            {
                "token": "fixture-token",
                "expires_at": "2099-01-01T00:00:00Z",
                "permissions": {
                    "contents": "write",
                    "pull_requests": "write",
                    "metadata": "read",
                },
            },
        )

    def do_GET(self) -> None:  # noqa: N802
        self.__class__.requests.append("GET " + self.path)
        if self.path == "/apps/fixture-app":
            self._json(
                200,
                {"permissions": {"contents": "write", "pull_requests": "write", "metadata": "read"}},
            )
        elif self.path == "/installation/repositories?per_page=100":
            self._json(200, {"repositories": [{"full_name": REPO}]})
        elif self.path == "/repos/fixture-owner/fixture-repo":
            self._json(self.repo_status, {"message": "forbidden" if self.repo_status == 403 else "ok"})
        else:
            self.send_error(404)

    def _json(self, status: int, value: object) -> None:
        body = json.dumps(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def start_stub(status: int) -> tuple[http.server.ThreadingHTTPServer, str]:
    GitHubStub.repo_status = status
    GitHubStub.requests = []
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), GitHubStub)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, "http://127.0.0.1:%d" % server.server_port


def make_fixture(root: Path) -> Path:
    key = root / "github-app.pem"
    subprocess.run(
        [
            "openssl",
            "genpkey",
            "-algorithm",
            "RSA",
            "-pkeyopt",
            "rsa_keygen_bits:2048",
            "-out",
            str(key),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    key.chmod(0o600)
    env_file = root / "github-app.env"
    env_file.write_text(
        "GITHUB_APP_ID=999\n"
        "GITHUB_APP_INSTALLATION_ID=123\n"
        "GITHUB_APP_PRIVATE_KEY_FILE=%s\n"
        "GITHUB_APP_SLUG=fixture-app\n"
        "GITHUB_APP_REPO=%s\n" % (key, REPO),
        encoding="utf-8",
    )
    return env_file


def run_check(script: Path, env_file: Path, api_base: str, root: Path, repo: str = "") -> subprocess.CompletedProcess[str]:
    args = [
        "python3",
        "-B",
        str(script),
        "check",
        "--env-file",
        str(env_file),
        "--api-base",
        api_base,
    ]
    if repo:
        args.extend(["--repo", repo])
    return subprocess.run(
        args,
        cwd=root,
        env={"PATH": os.environ["PATH"], "HOME": str(root / "home"), "PYTHONDONTWRITEBYTECODE": "1"},
        text=True,
        capture_output=True,
        check=False,
    )


def assert_common(output: str) -> None:
    if "fixture-owner/fixture-repo" not in output:
        raise AssertionError("repo name missing from output:\n" + output)
    if "PASS  app_slug" not in output:
        raise AssertionError("app fixture was not measured:\n" + output)


def main() -> int:
    outputs: list[tuple[str, int, str]] = []
    audit_before = AUDIT.read_bytes()
    with tempfile.TemporaryDirectory(prefix="cf-319-") as temp:
        root = Path(temp)
        env_file = make_fixture(root)

        server, api_base = start_stub(403)
        try:
            arm_a = run_check(TOKEN_SCRIPT, env_file, api_base, root, REPO)
        finally:
            server.shutdown()
            server.server_close()
        assert arm_a.returncode != 0
        assert "FAIL  repo_read" in arm_a.stdout
        assert "GET /repos/fixture-owner/fixture-repo -> 403" in arm_a.stdout
        assert "GET /repos/fixture-owner/fixture-repo" in GitHubStub.requests
        outputs.append(("Arm A — unreadable repo (403)", arm_a.returncode, arm_a.stdout))

        server, api_base = start_stub(200)
        try:
            arm_b = run_check(TOKEN_SCRIPT, env_file, api_base, root, REPO)
        finally:
            server.shutdown()
            server.server_close()
        assert arm_b.returncode == 0
        assert_common(arm_b.stdout)
        assert "PASS  repo_read" in arm_b.stdout
        assert "GET /repos/fixture-owner/fixture-repo with a fresh token -> 200" in arm_b.stdout
        assert "GET /repos/fixture-owner/fixture-repo" in GitHubStub.requests
        outputs.append(("Arm B — readable repo (200)", arm_b.returncode, arm_b.stdout))

        copy_root = root / "outside-git"
        copy_root.mkdir()
        copied_script = copy_root / "github-app-token.py"
        shutil.copyfile(TOKEN_SCRIPT, copied_script)
        shutil.copyfile(ROOT / "scripts" / "github-app-setup.sh", copy_root / "github-app-setup.sh")
        shutil.copyfile(ROOT / "scripts" / "lib.sh", copy_root / "lib.sh")
        no_repo_env = copy_root / "no-repo.env"
        no_repo_env.write_text(
            "\n".join(
                line
                for line in env_file.read_text(encoding="utf-8").splitlines()
                if not line.startswith("GITHUB_APP_REPO=")
            )
            + "\n",
            encoding="utf-8",
        )
        server, api_base = start_stub(200)
        try:
            arm_c = run_check(copied_script, no_repo_env, api_base, copy_root)
        finally:
            server.shutdown()
            server.server_close()
        assert arm_c.returncode != 0
        assert "FAIL  repo_read — no repository named" in arm_c.stdout
        assert "GITHUB APP: PASS" not in arm_c.stdout
        assert "reads the target repo" not in arm_c.stdout
        assert not any(path.startswith("GET /repos/") for path in GitHubStub.requests)
        outputs.append(("Arm C — no repo named", arm_c.returncode, arm_c.stdout))

    assert_transcript_matches_fixture(outputs)
    if AUDIT.read_bytes() != audit_before:
        raise AssertionError("CF-319 audit fixture changed while it was being checked")
    for label, code, _output in outputs:
        print("%s: exit %d" % (label, code))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
