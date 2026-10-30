#!/usr/bin/env python3
"""Hermetic local CF-002 tests: synthetic credentials, real loopback HTTP only."""

import copy
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, HTTPServer
import http.client
import importlib.util

import json
import os
from pathlib import Path
import secrets
import select
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    os.environ.get("CF_INFERENCE_UNDER_TEST", ROOT / "scripts/inference-proxy.py")
)
spec = importlib.util.spec_from_file_location("cf_inference", SOURCE)
proxy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proxy)


class FakeUpstream(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        # Capture a redirect-following credential leak even if POST became GET.
        self.server.calls.append((dict(self.headers), None))
        self.send_response(401)
        self.end_headers()

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        self.server.calls.append((dict(self.headers), json.loads(body)))
        mode, provider, model = (
            self.server.plan.pop(0)
            if self.server.plan
            else (self.server.mode, "provider-a", "model-a")
        )
        if mode == "slow":
            time.sleep(0.15)
        if mode in ("error", "redirect", "auth_error"):
            self.send_response({"error": 503, "redirect": 302, "auth_error": 401}[mode])
            self.send_header("Location", self.server.redirect)
            self.send_header("Authorization", self.server.key)
            self.end_headers()
            self.wfile.write(self.server.key.encode())
            return
        data = {
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": "local answer"},
                    "finish_reason": "stop",
                }
            ],
        }
        if mode == "wrong_pair":
            provider, model = "provider-b", "model-b"
            data["model"] = model
        if mode == "conflicting_model":
            data["model"] = "unattested-label"
        if mode == "echo_key":
            data["choices"][0]["message"]["content"] = self.server.key
        if mode == "tool_call":
            data["choices"][0]["message"]["tool_calls"] = []
        if mode == "oversize":
            data["extra"] = "x" * proxy.MAX_RESPONSE
        raw = proxy.canonical(data)
        request_id = self.headers["X-CF-Request-ID"]
        if mode == "replay":
            request_id = "00000000-0000-0000-0000-000000000000"
        signature = hmac.new(
            self.server.attestation_key.encode(),
            proxy.attestation_payload(request_id, provider, model, raw),
            hashlib.sha256,
        ).hexdigest()
        if mode == "bad_signature":
            signature = "0" * 64
        self.send_response(200)
        self.send_header("Authorization", self.server.key)
        if mode != "missing_attestation":
            self.send_header("X-CF-Served-Provider", provider)
            self.send_header("X-CF-Served-Model", model)
            self.send_header("X-CF-Attestation", signature)
            if mode == "duplicate_attestation":
                self.send_header("X-CF-Attestation", signature)
        self.end_headers()
        try:
            self.wfile.write(raw)
        except BrokenPipeError:
            pass  # The timeout test deliberately closes the client first.


class InferenceContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cf-inference-local-")
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name) / "state"
        self.directory.mkdir(mode=0o700)
        self.token = secrets.token_urlsafe(32)
        self.key = "synthetic_provider_sentinel_" + secrets.token_hex(16)
        self.attestation_key = secrets.token_urlsafe(40)
        self.write("provider.key", self.key)
        self.write("attestation.key", self.attestation_key)
        self.fake = HTTPServer(("127.0.0.1", 0), FakeUpstream)
        self.fake.calls = []
        self.fake.mode = "normal"
        self.fake.plan = []
        self.fake.key = self.key
        self.fake.attestation_key = self.attestation_key
        self.fake.redirect = "http://127.0.0.1:1/v1/chat/completions"
        thread = threading.Thread(target=self.fake.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.stop_server, self.fake, thread)
        self.body = dict(
            service_identity="service-a",
            node="node-a",
            project="project-a",
            repository="example/repo",
            provider="provider-a",
            model="model-a",
            messages=[dict(role="user", content="private synthetic prompt")],
            stream=False,
            max_tokens=64,
            temperature=0.2,
        )
        self.policy = dict(
            version=1,
            identities=[
                dict(
                    **{k: self.body[k] for k in proxy.SCOPE},
                    token_hash=proxy.digest(self.token.encode()),
                    expires_at=int(time.time()) + 3600,
                    revoked=False,
                    allowed=[dict(provider="provider-a", model="model-a")],
                )
            ],
            routes=[
                dict(
                    provider="provider-a",
                    model="model-a",
                    url=f"http://127.0.0.1:{self.fake.server_port}/v1/chat/completions",
                    key_file="provider.key",
                    attestation_file="attestation.key",
                    fallback=[],
                )
            ],
        )
        self.publish()
        self.state = proxy.State(str(self.directory))
        self.addCleanup(self.state.close)
        self.gateway = proxy.Gateway(self.state)
        self.addCleanup(lambda: self.gateway.evidence.close())
        self.resolutions = []
        original = self.state.secret

        def spy(name):
            self.resolutions.append(name)
            return original(name)

        self.state.secret = spy
        self.server = proxy.Server(("127.0.0.1", 0), proxy.Handler)
        self.server.gateway = self.gateway
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server, self.server, self.thread)

    @staticmethod
    def stop_server(server, thread):
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)

    def write(self, name, text):
        path = self.directory / name
        path.write_text(text)
        path.chmod(0o600)
        return path

    def publish(self):
        path = self.write("next.json", json.dumps(self.policy))
        path.replace(self.directory / "policy.json")

    def request(
        self,
        body=None,
        authorization=None,
        headers=None,
        path="/v1/chat/completions",
        method="POST",
    ):
        raw = proxy.canonical(self.body if body is None else body)
        return self.raw_request(raw, authorization, headers, path, method)

    def raw_request(
        self,
        raw,
        authorization=None,
        headers=None,
        path="/v1/chat/completions",
        method="POST",
    ):
        conn = http.client.HTTPConnection(
            "127.0.0.1", self.server.server_port, timeout=8
        )
        values = {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + self.token,
        }
        if authorization is not None:
            values["Authorization"] = authorization
        values.update(headers or {})
        try:
            conn.request(method, path, raw, values)
            response = conn.getresponse()
            result = response.status, response.read(), dict(response.headers)
            self.assertNotIn(
                self.key, repr(result), "upstream credential leaked to client"
            )
            self.assertNotIn(self.attestation_key, repr(result))
            self.assertNotIn(self.token, repr(result))
            return result
        finally:
            conn.close()

    def rows(self):
        return [
            json.loads(line)
            for line in (self.directory / "evidence.jsonl").read_text().splitlines()
        ]

    def denied(self, **kwargs):
        self.resolutions.clear()
        before = len(self.fake.calls)
        status, raw, _ = self.request(**kwargs)
        self.assertEqual(status, 403, raw)
        self.assertEqual(self.resolutions, [], "denial resolved upstream credentials")
        self.assertEqual(len(self.fake.calls), before, "denial reached upstream")

    def test_http_success_and_evidence(self):
        status, raw, headers = self.request()
        self.assertEqual(status, 200, raw)
        self.assertEqual(
            json.loads(raw)["choices"][0]["message"]["content"], "local answer"
        )
        self.assertNotIn("Authorization", headers)
        self.assertNotIn("X-CF-Attestation", headers)
        self.assertEqual(self.resolutions, ["provider.key", "attestation.key"])
        sent_headers, sent_body = self.fake.calls[0]
        self.assertEqual(sent_headers["Authorization"], "Bearer " + self.key)
        self.assertNotIn(self.token, repr(self.fake.calls))
        self.assertEqual(
            set(sent_body), {"model", "messages", "stream", "temperature", "max_tokens"}
        )
        rows = self.rows()
        self.assertEqual([row["outcome"] for row in rows], ["intent", "success"])
        self.assertEqual(rows[-1]["requested"], rows[-1]["served"])
        self.assertEqual(rows[-1]["scope"], {k: self.body[k] for k in proxy.SCOPE})
        self.assertEqual(rows[-1]["provenance"], "hmac-sha256-trusted-adapter-v1")
        self.assertNotIn("private synthetic prompt", repr(rows))
        self.assertNotIn("local answer", repr(rows))
        self.assertNotIn(self.key, repr(rows))
        self.assertNotIn(self.token, repr(rows))

    def test_denials_before_key_resolution(self):
        for authorization in (
            "",
            "Basic opaque",
            "Bearer short",
            "Bearer " + secrets.token_urlsafe(32),
        ):
            with self.subTest(auth=authorization[:6]):
                self.denied(authorization=authorization)
        # Truly absent Authorization, not just an empty header.
        self.resolutions.clear()
        conn = http.client.HTTPConnection(
            "127.0.0.1", self.server.server_port, timeout=8
        )
        conn.request(
            "POST",
            "/v1/chat/completions",
            proxy.canonical(self.body),
            {"Content-Type": "application/json"},
        )
        response = conn.getresponse()
        self.assertEqual(response.status, 403)
        response.read()
        conn.close()
        self.assertEqual(self.resolutions, [])
        for field in proxy.SCOPE | proxy.PAIR:
            with self.subTest(field=field):
                self.denied(body=dict(self.body, **{field: "other"}))
        for field, value in (("revoked", True), ("expires_at", int(time.time()) - 1)):
            original = self.policy["identities"][0][field]
            self.policy["identities"][0][field] = value
            self.publish()
            self.denied()
            self.policy["identities"][0][field] = original
        self.publish()

    def test_schema_and_override_denials(self):
        for extra in (
            {"stream": True},
            {"stream": 0},
            {"url": "http://127.0.0.1:1"},
            {"headers": {"Authorization": self.key}},
            {"key": self.key},
            {"fallback": []},
            {"tools": []},
            {"max_tokens": True},
            {"temperature": float("inf")},
            {"messages": []},
            {"messages": [{"role": "tool", "content": "x"}]},
        ):
            with self.subTest(fields=list(extra)):
                body = dict(self.body, **extra)
                self.resolutions.clear()
                raw = json.dumps(body).encode()
                self.assertEqual(self.raw_request(raw)[0], 403)
                self.assertEqual(self.resolutions, [])
        for headers in (
            {"X-Upstream-URL": "http://127.0.0.1:1"},
            {"X-API-Key": self.key},
            {"Transfer-Encoding": "chunked"},
            {"Content-Encoding": "gzip"},
            {"Accept-Encoding": "gzip"},
            {"Content-Type": "text/plain"},
            {"Expect": "100-continue"},
        ):
            self.denied(headers=headers)
        self.denied(path="/v1/chat/completions?endpoint=other")
        self.denied(path="/v1/models")
        self.resolutions.clear()
        self.assertEqual(self.request(method="GET")[0], 501)
        self.assertEqual(self.resolutions, [])
        for raw in (b"{", b"{}", b"[]", b'{"model":"a","model":"b"}'):
            self.assertEqual(self.raw_request(raw)[0], 403)
        self.assertEqual(self.resolutions, [])
        self.assertNotIn(self.key, (self.directory / "evidence.jsonl").read_text())

    def test_request_and_upstream_socket_timeouts(self):
        with mock.patch.object(proxy, "TIMEOUT", 0.04):
            with socket.create_connection(
                ("127.0.0.1", self.server.server_port), timeout=2
            ) as conn:
                conn.sendall(
                    b"POST /v1/chat/completions HTTP/1.0\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{"
                )
                self.assertIn(b"403", conn.recv(4096))
            self.assertEqual(
                self.resolutions, [], "incomplete timed-out body reached key resolver"
            )
            self.fake.mode = "slow"
            self.assertEqual(self.request()[0], 502)
            self.assertEqual(self.rows()[-1]["outcome"], "unavailable")

    def test_existing_route_disallowed_before_keys(self):
        self.policy["routes"].append(
            dict(self.policy["routes"][0], provider="provider-b")
        )
        self.publish()
        self.denied(body=dict(self.body, provider="provider-b"))
        # Allow it explicitly and prove that the same body gets past key resolution;
        # the attestor still refuses its mismatched actual provider-a identity.
        self.policy["identities"][0]["allowed"].append(
            dict(provider="provider-b", model="model-a")
        )
        self.publish()
        self.assertEqual(
            self.request(body=dict(self.body, provider="provider-b"))[0], 502
        )
        self.assertEqual(self.resolutions, ["provider.key", "attestation.key"])

    def test_duplicate_and_oversize_http(self):
        for headers, body in (
            ([("Authorization", "Bearer " + self.token)] * 2, b"{}"),
            ([("Content-Length", "65537")], b""),
            ([("Content-Length", "2"), ("Content-Length", "2")], b"{}"),
        ):
            with socket.create_connection(
                ("127.0.0.1", self.server.server_port), timeout=8
            ) as connection:
                base = "POST /v1/chat/completions HTTP/1.0\r\nContent-Type: application/json\r\n"
                lines = "".join(k + ": " + v + "\r\n" for k, v in headers)
                connection.sendall((base + lines + "\r\n").encode() + body)
                self.assertIn(b"403", connection.recv(4096))
        self.assertEqual(self.resolutions, [])

    def test_attestation_failures_and_error_sentinel(self):
        for mode in (
            "missing_attestation",
            "bad_signature",
            "replay",
            "wrong_pair",
            "conflicting_model",
            "duplicate_attestation",
            "echo_key",
            "tool_call",
            "oversize",
            "auth_error",
            "error",
            "redirect",
        ):
            with self.subTest(mode=mode):
                self.fake.mode = mode
                status, raw, _ = self.request()
                self.assertEqual(status, 502, raw)
                self.assertNotEqual(self.rows()[-1]["outcome"], "success")
                self.assertIsNone(self.rows()[-1]["served"])
        text = (self.directory / "evidence.jsonl").read_text()
        self.assertNotIn(self.key, text)
        self.assertNotIn(self.token, text)

    def fallback(self, allow):
        target = dict(provider="provider-b", model="model-a")
        fallback = dict(self.policy["routes"][0], **target, fallback=[])
        self.policy["routes"].append(fallback)
        self.policy["routes"][0]["fallback"] = [target]
        if allow:
            self.policy["identities"][0]["allowed"].append(target)
        self.publish()

    def test_fallback_authorized_and_disallowed(self):
        self.fallback(False)
        self.denied()
        self.policy["identities"][0]["allowed"].append(
            dict(provider="provider-b", model="model-a")
        )
        self.publish()
        # Both attempts pass through the real HTTP transport and HMAC verifier.
        self.fake.plan = [
            ("error", "provider-a", "model-a"),
            ("normal", "provider-b", "model-a"),
        ]
        status, raw, _ = self.request()
        self.assertEqual(status, 200, raw)
        self.assertEqual(
            [row["outcome"] for row in self.rows()][-3:],
            ["intent", "unavailable", "success"],
        )
        self.assertEqual(self.rows()[-1]["requested"]["provider"], "provider-a")
        self.assertEqual(self.rows()[-1]["served"]["provider"], "provider-b")
        self.assertEqual(self.fake.calls[-1][1]["model"], "model-a")
        # A fallback's valid HMAC for the wrong pair must fail, no inferred provenance.
        self.fake.plan = [
            ("error", "provider-a", "model-a"),
            ("normal", "provider-a", "model-a"),
        ]
        self.assertEqual(self.request()[0], 502)
        self.assertIsNone(self.rows()[-1]["served"])

    def test_no_fallback_on_attestation_or_auth_error(self):
        self.fallback(True)
        for mode in ("missing_attestation", "auth_error"):
            self.fake.mode = mode
            self.fake.calls.clear()
            self.assertEqual(self.request()[0], 502)
            self.assertEqual(len(self.fake.calls), 1)

    def test_redirect_and_environment_proxy_not_forwarded(self):
        sink = HTTPServer(("127.0.0.1", 0), FakeUpstream)
        sink.calls, sink.mode, sink.plan = [], "normal", []
        sink.key, sink.attestation_key, sink.redirect = (
            self.key,
            self.attestation_key,
            "",
        )
        thread = threading.Thread(target=sink.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.stop_server, sink, thread)
        url = f"http://127.0.0.1:{sink.server_port}/v1/chat/completions"
        self.fake.redirect = url
        self.fake.mode = "redirect"
        with mock.patch.dict(
            os.environ,
            {
                "http_proxy": url,
                "HTTP_PROXY": url,
                "https_proxy": url,
                "HTTPS_PROXY": url,
                "no_proxy": "",
                "NO_PROXY": "",
            },
        ):
            redirected_status = self.request()[0]
            self.fake.mode = "normal"
            normal_status = self.request()[0]
        self.assertEqual(
            sink.calls, [], "provider credential followed redirect/environment proxy"
        )
        self.assertEqual(redirected_status, 502)
        self.assertEqual(normal_status, 200)

    def test_host_files_and_policy_fail_closed(self):
        original = copy.deepcopy(self.policy)
        mutations = [
            lambda p: p.update(unknown="x"),
            lambda p: p["identities"][0].update(revoked="false"),
            lambda p: p["identities"][0].update(expires_at=True),
            lambda p: p["identities"].append(copy.deepcopy(p["identities"][0])),
            lambda p: p["routes"][0].update(
                url="http://example.invalid/v1/chat/completions"
            ),
            lambda p: p["routes"][0].update(
                url="https://user:pass@example.invalid/v1/chat/completions"
            ),
            lambda p: p["routes"][0].update(key_file="../provider.key"),
            lambda p: p["routes"][0].update(attestation_file="provider.key"),
        ]
        for mutate in mutations:
            self.policy = copy.deepcopy(original)
            mutate(self.policy)
            self.publish()
            self.denied()
        self.policy = original
        self.publish()
        policy_path = self.directory / "policy.json"
        policy_path.chmod(0o644)
        self.denied()
        self.publish()
        key_path = self.directory / "provider.key"
        original_key = key_path.read_text()
        for kind in ("mode", "symlink", "hardlink", "fifo", "directory"):
            with self.subTest(kind=kind):
                if kind == "mode":
                    key_path.chmod(0o644)
                else:
                    key_path.unlink()
                    if kind == "symlink":
                        key_path.symlink_to(self.write("copy.key", original_key))
                    elif kind == "hardlink":
                        os.link(self.write("copy.key", original_key), key_path)
                    elif kind == "fifo":
                        os.mkfifo(key_path)
                    else:
                        key_path.mkdir()
                before = len(self.fake.calls)
                self.assertEqual(self.request()[0], 502)
                self.assertEqual(len(self.fake.calls), before)
                if kind == "directory":
                    key_path.rmdir()
                else:
                    key_path.unlink()
                self.write("provider.key", original_key)
        self.directory.chmod(0o755)
        with self.assertRaises(proxy.Refused):
            proxy.State(str(self.directory))
        self.directory.chmod(0o700)
        alias = Path(self.tmp.name) / "alias"
        alias.symlink_to(self.directory, target_is_directory=True)
        with self.assertRaises(OSError):
            proxy.State(str(alias))

    def test_restart_revocation_rotation_and_corruption(self):
        self.assertEqual(self.request()[0], 200)
        before = self.rows()
        self.gateway.evidence.close()
        self.gateway.evidence = proxy.Evidence(self.state)
        self.assertEqual(self.request()[0], 200)
        self.assertEqual(self.rows()[: len(before)], before)
        self.policy["identities"][0]["revoked"] = True
        self.publish()
        self.denied()
        self.policy["identities"][0]["revoked"] = False
        self.policy["identities"][0]["token_hash"] = proxy.digest(
            secrets.token_urlsafe(32).encode()
        )
        self.publish()
        self.denied()
        self.gateway.evidence.close()
        path = self.directory / "evidence.jsonl"
        valid = path.read_bytes()
        for raw in (
            valid[:-1],
            b"not json\n",
            valid.replace(b'"success"', b'"denied"', 1),
            b"\n".join(reversed(valid.splitlines())) + b"\n",
        ):
            path.write_bytes(raw)
            with self.assertRaises(Exception):
                proxy.Evidence(self.state)
        path.write_bytes(valid)
        self.gateway.evidence = proxy.Evidence(self.state)
        with self.assertRaises(BlockingIOError):
            proxy.Evidence(self.state)

    def test_evidence_write_failure_before_key_and_success(self):
        with mock.patch.object(
            proxy.os, "fsync", side_effect=OSError("private failure " + self.key)
        ):
            status, raw, _ = self.request()
        self.assertEqual(status, 503, raw)
        self.assertEqual(self.resolutions, [])
        self.assertEqual(self.request()[0], 503)
        self.gateway.evidence.close()
        self.gateway.evidence = proxy.Evidence(self.state)
        original = self.gateway.evidence.append

        def fail_success(*args, **kwargs):
            if args[5] == "success":
                self.gateway.evidence.failed = True
                raise OSError("private sentinel " + self.key)
            return original(*args, **kwargs)

        with mock.patch.object(self.gateway.evidence, "append", fail_success):
            self.assertEqual(
                self.request()[0], 503, "success returned without durable evidence"
            )
        self.assertNotEqual(self.rows()[-1]["outcome"], "success")
        self.resolutions.clear()
        self.assertEqual(self.request()[0], 503)
        self.assertEqual(self.resolutions, [])

    def test_evidence_replacement_and_partial_write(self):
        path = self.directory / "evidence.jsonl"
        path.rename(self.directory / "old.jsonl")
        self.write("evidence.jsonl", "")
        self.assertEqual(self.request()[0], 503)
        self.assertEqual(self.resolutions, [])
        path.unlink()
        (self.directory / "old.jsonl").rename(path)
        self.gateway.evidence.close()
        self.gateway.evidence = proxy.Evidence(self.state)
        real_write = os.write

        def short_write(fd, raw):
            return real_write(fd, raw[:7])

        with mock.patch.object(proxy.os, "write", short_write):
            self.assertEqual(self.request()[0], 503)
        self.assertEqual(self.resolutions, [])
        self.gateway.evidence.close()
        with self.assertRaises(Exception):
            proxy.Evidence(self.state)
        # Restore a valid empty file solely so cleanup has one owned descriptor.
        path.write_bytes(b"")
        self.gateway.evidence = proxy.Evidence(self.state)

    def test_real_cli_invocation_and_redacted_logs(self):
        # Real executable startup plus real HTTP, not a fake adapter success string.
        # Release the in-process journal lock before the new process starts.
        self.gateway.evidence.close()
        process = subprocess.Popen(
            [
                sys.executable,
                "-B",
                str(SOURCE),
                "--state-dir",
                str(self.directory),
                "--port",
                "0",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(lambda: process.poll() is None and process.kill())
        try:
            ready, _, _ = select.select([process.stdout], [], [], 8)
            self.assertTrue(ready, "gateway did not publish measured startup port")
            line = process.stdout.readline()
            self.assertRegex(line, r"^PASS inference-proxy loopback port=[0-9]+\n$")
            port = int(line.strip().split("=")[-1])
            conn = http.client.HTTPConnection("127.0.0.1", port, timeout=8)
            conn.request(
                "POST",
                "/v1/chat/completions",
                proxy.canonical(self.body),
                {
                    "Authorization": "Bearer " + self.token,
                    "Content-Type": "application/json",
                },
            )
            response = conn.getresponse()
            self.assertEqual(response.status, 200)
            self.assertNotIn(self.key.encode(), response.read())
            conn.close()
            self.fake.mode = "auth_error"
            conn = http.client.HTTPConnection("127.0.0.1", port, timeout=8)
            conn.request(
                "POST",
                "/v1/chat/completions",
                proxy.canonical(self.body),
                {
                    "Authorization": "Bearer " + self.token,
                    "Content-Type": "application/json",
                },
            )
            response = conn.getresponse()
            self.assertEqual(response.status, 502)
            self.assertNotIn(self.key.encode(), response.read())
            conn.close()
        finally:
            process.terminate()
            stdout, stderr = process.communicate(timeout=8)
            self.gateway.evidence = proxy.Evidence(self.state)
        self.assertEqual(
            stdout + stderr, "", "unexpected runtime/access/exception logging"
        )
        self.assertNotIn(self.key, line + stdout + stderr)
        self.assertNotIn(self.token, repr(process.args))
        self.assertNotIn(self.key, repr(process.args))

    def test_installer_sentinel_and_no_transport_copy(self):
        home = Path(self.tmp.name) / "node-home"
        (home / ".hermes").mkdir(parents=True)
        env_file = home / ".hermes/.env"
        # A FIFO catches even an attempted legacy read by blocking until timeout.
        os.mkfifo(env_file)
        env = {
            "PATH": "/usr/bin:/bin",
            "HOME": str(home),
            "SYNTHETIC_PROVIDER_SENTINEL": self.key,
        }
        for mode in ("--apply", "--check"):
            process = subprocess.run(
                ["bash", str(ROOT / "scripts/harness/install-hermes.sh"), mode],
                env=env,
                capture_output=True,
                text=True,
                timeout=4,
            )
            self.assertEqual(process.returncode, 1)
            self.assertIn("FAIL  inference_integration", process.stdout)
            self.assertNotIn(self.key, process.stdout + process.stderr)
        env_file.unlink()
        env_file.write_text("SYNTHETIC=" + self.key)
        before = env_file.read_bytes()
        process = subprocess.run(
            ["bash", str(ROOT / "scripts/harness/install-hermes.sh"), "--apply"],
            env=env,
            capture_output=True,
            text=True,
            timeout=4,
        )
        self.assertEqual(process.returncode, 1)
        self.assertEqual(env_file.read_bytes(), before)
        self.assertEqual(
            sorted(str(p.relative_to(home)) for p in home.rglob("*") if p.is_file()),
            [".hermes/.env"],
        )
        self.assertEqual(self.request()[0], 200)
        for row in self.rows():
            self.assertNotIn(self.key, repr(row))
        self.assertFalse((home / ".node").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
