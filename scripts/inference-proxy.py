#!/usr/bin/env python3
"""Loopback-only CF-002 host boundary. Contract: specs/HARNESS.md.

Not a deployed gateway, node adapter, routing registry or generic OpenAI proxy.
No access logs; all public failures are fixed codes, never exception strings.
"""

import argparse
import fcntl
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import math
import os
import re
import socket
import stat
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

MAX_BODY = 65536
MAX_RESPONSE = 131072
TIMEOUT = 5
SCOPE = {"service_identity", "node", "project", "repository"}
PAIR = {"provider", "model"}
LABEL = re.compile(r"[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}\Z")
HEX = re.compile(r"[0-9a-f]{64}\Z")
OUTCOMES = {"denied", "intent", "unavailable", "upstream_rejected", "success"}
PROVENANCE = {"none", "hmac-sha256-trusted-adapter-v1"}


class Refused(Exception):
    """Deliberately contains only a fixed internal code."""


class Unavailable(Exception):
    """Only retryable transport/502/503/504 failures."""


def require(condition, code="invalid"):
    if not condition:
        raise Refused(code)


def canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("ascii")


def digest(value):
    return hashlib.sha256(value).hexdigest()


def unique_object(items):
    result = {}
    for key, value in items:
        require(key not in result)
        result[key] = value
    return result


def decode(raw):
    return json.loads(
        raw, object_pairs_hook=unique_object, parse_constant=lambda _: require(False)
    )


def fields(value, expected):
    require(type(value) is dict and set(value) == expected)


def label(value):
    require(type(value) is str and LABEL.fullmatch(value) is not None)


def pair(value):
    fields(value, PAIR)
    for item in value.values():
        label(item)
    return (value["provider"], value["model"])


def pair_dict(value):
    return dict(zip(("provider", "model"), value))


def pairs(values):
    require(type(values) is list and len(values) <= 32)
    result = [pair(value) for value in values]
    require(len(result) == len(set(result)))
    return result


class State:
    """Pin the private directory, walk ancestors without following symlinks."""

    def __init__(self, directory):
        require(type(directory) is str and directory.startswith("/"))
        components = directory.split("/")[1:]
        require(components and all(c not in ("", ".", "..") for c in components))
        fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
        try:
            for component in components:
                next_fd = os.open(
                    component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd
                )
                os.close(fd)
                fd = next_fd
            info = os.fstat(fd)
            require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o700)
            self.fd = fd
        except BaseException:
            os.close(fd)
            raise

    def close(self):
        os.close(self.fd)

    @staticmethod
    def filename(name):
        require(
            type(name) is str
            and re.fullmatch(
                r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}(?:\.[A-Za-z0-9_-]+)?", name
            )
        )

    def open(self, name, flags=os.O_RDONLY):
        directory = os.fstat(self.fd)
        require(
            directory.st_uid == os.getuid() and stat.S_IMODE(directory.st_mode) == 0o700
        )
        self.filename(name)
        fd = os.open(name, flags | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=self.fd)
        try:
            info = os.fstat(fd)
            require(
                stat.S_ISREG(info.st_mode)
                and info.st_nlink == 1
                and info.st_uid == os.getuid()
                and stat.S_IMODE(info.st_mode) == 0o600
            )
            return fd
        except BaseException:
            os.close(fd)
            raise

    def read(self, name, limit):
        fd = self.open(name)
        try:
            require(os.fstat(fd).st_size <= limit)
            with os.fdopen(fd, "rb", closefd=False) as stream:
                value = stream.read(limit + 1)
            require(len(value) <= limit)
            return value
        finally:
            os.close(fd)

    def secret(self, name):
        # This is the ONLY upstream credential resolver; called after authorization.
        value = self.read(name, 512).decode("ascii")
        require(re.fullmatch(r"[A-Za-z0-9_-]{32,128}", value) is not None)
        return value

    def policy(self):
        policy = decode(self.read("policy.json", MAX_BODY))
        fields(policy, {"version", "identities", "routes"})
        require(type(policy["version"]) is int and policy["version"] == 1)
        require(
            type(policy["identities"]) is list and 1 <= len(policy["identities"]) <= 128
        )
        identities, hashes = set(), set()
        for identity in policy["identities"]:
            fields(identity, SCOPE | {"token_hash", "expires_at", "revoked", "allowed"})
            for name in SCOPE:
                label(identity[name])
            require(identity["service_identity"] not in identities)
            identities.add(identity["service_identity"])
            token_hash = identity["token_hash"]
            require(type(token_hash) is str and HEX.fullmatch(token_hash) is not None)
            require(token_hash not in hashes)
            hashes.add(token_hash)
            require(type(identity["expires_at"]) is int and identity["expires_at"] > 0)
            require(type(identity["revoked"]) is bool)
            require(bool(pairs(identity["allowed"])))
        require(type(policy["routes"]) is list and 1 <= len(policy["routes"]) <= 128)
        routes = {}
        for route in policy["routes"]:
            fields(route, PAIR | {"url", "key_file", "attestation_file", "fallback"})
            route_pair = pair({k: route[k] for k in PAIR})
            require(route_pair not in routes)
            self.filename(route["key_file"])
            self.filename(route["attestation_file"])
            require(route["key_file"] != route["attestation_file"])
            require(
                type(route["url"]) is str
                and route["url"].isascii()
                and not any(c.isspace() or ord(c) < 32 for c in route["url"])
            )
            url = urllib.parse.urlsplit(route["url"])
            require(
                url.scheme in ("https", "http")
                and bool(url.hostname)
                and url.username is None
                and url.password is None
                and not url.query
                and not url.fragment
                and url.path == "/v1/chat/completions"
                and (url.scheme == "https" or url.hostname == "127.0.0.1")
            )
            require(url.port is None or 1 <= url.port <= 65535)
            pairs(route["fallback"])
            routes[route_pair] = route
        for identity in policy["identities"]:
            require(all(p in routes for p in pairs(identity["allowed"])))
        for route_pair, route in routes.items():
            require(
                all(p in routes and p != route_pair for p in pairs(route["fallback"]))
            )
        return policy["identities"], routes


class Evidence:
    """Append-only application journal, NOT immutable against the host owner."""

    KEYS = {
        "seq",
        "previous",
        "hash",
        "time_ns",
        "request_id",
        "scope",
        "requested",
        "attempted",
        "served",
        "outcome",
        "provenance",
    }

    def __init__(self, state):
        self.state = state
        self.fd = state.open("evidence.jsonl", os.O_RDWR | os.O_APPEND | os.O_CREAT)
        self.failed = False
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.seq, self.previous, self.size = self.validate()
            os.fsync(self.fd)
            os.fsync(state.fd)
        except BaseException:
            os.close(self.fd)
            raise

    def close(self):
        os.close(self.fd)

    def validate(self):
        previous, seq = "0" * 64, 0
        with os.fdopen(os.dup(self.fd), "rb") as stream:
            stream.seek(0)
            while True:
                raw = stream.readline(8193)
                if not raw:
                    break
                require(len(raw) <= 8192 and raw.endswith(b"\n"), "evidence")
                row = decode(raw)
                fields(row, self.KEYS)
                require(
                    type(row["seq"]) is int
                    and row["seq"] == seq + 1
                    and row["previous"] == previous,
                    "evidence",
                )
                require(type(row["time_ns"]) is int and row["time_ns"] > 0)
                require(
                    type(row["request_id"]) is str
                    and str(uuid.UUID(row["request_id"])) == row["request_id"]
                )
                if row["scope"] is not None:
                    fields(row["scope"], SCOPE)
                    for value in row["scope"].values():
                        label(value)
                for key in ("requested", "attempted", "served"):
                    if row[key] is not None:
                        pair(row[key])
                require(row["outcome"] in OUTCOMES and row["provenance"] in PROVENANCE)
                claimed = row.pop("hash")
                require(
                    type(claimed) is str
                    and hmac.compare_digest(claimed, digest(canonical(row))),
                    "evidence",
                )
                previous, seq = claimed, seq + 1
            return seq, previous, stream.tell()

    def healthy(self):
        require(not self.failed, "evidence")
        info = os.fstat(self.fd)
        current = os.stat("evidence.jsonl", dir_fd=self.state.fd, follow_symlinks=False)
        require(
            (info.st_ino, info.st_dev) == (current.st_ino, current.st_dev)
            and info.st_size == self.size
            and info.st_nlink == 1
            and stat.S_IMODE(info.st_mode) == 0o600,
            "evidence",
        )

    def append(
        self,
        request_id,
        scope,
        requested,
        attempted,
        served,
        outcome,
        provenance="none",
    ):
        try:
            self.healthy()
            row = dict(
                seq=self.seq + 1,
                previous=self.previous,
                time_ns=time.time_ns(),
                request_id=request_id,
                scope=scope,
                requested=requested,
                attempted=attempted,
                served=served,
                outcome=outcome,
                provenance=provenance,
            )
            row["hash"] = digest(canonical(row))
            raw = canonical(row) + b"\n"
            require(os.write(self.fd, raw) == len(raw), "evidence")
            os.fsync(self.fd)
            self.seq += 1
            self.previous = row["hash"]
            self.size += len(raw)
        except Exception:
            self.failed = True
            raise Refused("evidence") from None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def attestation_payload(request_id, provider, model, body):
    return canonical(
        dict(
            request_id=request_id,
            provider=provider,
            model=model,
            body_sha256=digest(body),
        )
    )


def upstream(route, body, request_id, key, attestation_key):
    payload = dict(body)
    payload["model"] = route["model"]
    request = urllib.request.Request(
        route["url"],
        data=canonical(payload),
        headers={
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
            "X-CF-Request-ID": request_id,
        },
        method="POST",
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=TIMEOUT) as response:
            require(response.status == 200, "upstream")
            raw = response.read(MAX_RESPONSE + 1)
            require(len(raw) <= MAX_RESPONSE, "upstream")
            names = ("X-CF-Served-Provider", "X-CF-Served-Model", "X-CF-Attestation")
            values = []
            for name in names:
                headers = response.headers.get_all(name, [])
                require(len(headers) == 1, "attestation")
                values.append(headers[0])
    except urllib.error.HTTPError as error:
        code = error.code
        error.close()
        if code in (502, 503, 504):
            raise Unavailable() from None
        raise Refused("upstream") from None
    except (urllib.error.URLError, TimeoutError, socket.timeout, ConnectionError):
        raise Unavailable() from None
    provider, model, signature = values
    label(provider)
    label(model)
    expected = hmac.new(
        attestation_key.encode("ascii"),
        attestation_payload(request_id, provider, model, raw),
        hashlib.sha256,
    ).hexdigest()
    require(
        HEX.fullmatch(signature) is not None
        and hmac.compare_digest(signature, expected),
        "attestation",
    )
    require((provider, model) == (route["provider"], route["model"]), "attestation")
    data = decode(raw)
    require(type(data) is dict and data.get("model") == model, "upstream")
    choices = data.get("choices")
    require(type(choices) is list and len(choices) == 1, "upstream")
    choice = choices[0]
    fields(choice, {"index", "message", "finish_reason"})
    require(
        type(choice["index"]) is int
        and choice["index"] == 0
        and choice["finish_reason"] in ("stop", "length"),
        "upstream",
    )
    fields(choice["message"], {"role", "content"})
    content = choice["message"]["content"]
    require(
        choice["message"]["role"] == "assistant" and type(content) is str, "upstream"
    )
    require(key not in content and attestation_key not in content, "upstream")
    return dict(
        id=request_id, object="chat.completion", model=model, choices=choices
    ), pair_dict((provider, model))


def validate_body(body):
    required = SCOPE | PAIR | {"messages"}
    require(
        type(body) is dict
        and required <= set(body)
        and set(body) <= required | {"stream", "temperature", "max_tokens"}
    )
    for name in SCOPE | PAIR:
        label(body[name])
    require(body.get("stream", False) is False)
    if "max_tokens" in body:
        require(type(body["max_tokens"]) is int and 1 <= body["max_tokens"] <= 4096)
    if "temperature" in body:
        value = body["temperature"]
        require(
            type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 2
        )
    messages = body["messages"]
    require(type(messages) is list and 1 <= len(messages) <= 32)
    for message in messages:
        fields(message, {"role", "content"})
        require(
            message["role"] in ("system", "user", "assistant")
            and type(message["content"]) is str
            and len(message["content"]) <= 16000
        )


class Gateway:
    def __init__(self, state):
        self.state = state
        state.policy()  # startup policy validation, never resolves upstream keys
        self.evidence = Evidence(state)

    def authorize(self, body, authorization):
        validate_body(body)
        require(
            type(authorization) is str
            and re.fullmatch(r"Bearer [A-Za-z0-9_-]{32,128}", authorization),
            "denied",
        )
        identities, routes = self.state.policy()
        token_hash = digest(authorization[7:].encode("ascii"))
        identity = next(
            (
                item
                for item in identities
                if hmac.compare_digest(item["token_hash"], token_hash)
            ),
            None,
        )
        require(identity is not None, "denied")
        require(
            not identity["revoked"] and identity["expires_at"] > time.time(), "denied"
        )
        require(all(body[k] == identity[k] for k in SCOPE), "denied")
        requested = (body["provider"], body["model"])
        require(requested in routes, "denied")
        candidates = [requested] + pairs(routes[requested]["fallback"])
        allowed = pairs(identity["allowed"])
        require(all(candidate in allowed for candidate in candidates), "denied")
        return {k: identity[k] for k in SCOPE}, candidates, routes

    def handle(self, raw, authorization, wire_valid=True):
        request_id = str(uuid.uuid4())
        try:
            self.evidence.healthy()
            require(wire_valid, "denied")
            body = decode(raw)
            scope, candidates, routes = self.authorize(body, authorization)
        except Exception:
            try:
                self.evidence.append(request_id, None, None, None, None, "denied")
            except Exception:
                return 503, {"error": "evidence_unavailable"}
            return 403, {"error": "request_denied"}
        requested = pair_dict(candidates[0])
        try:
            self.evidence.append(request_id, scope, requested, None, None, "intent")
            payload = {
                k: body[k]
                for k in ("messages", "stream", "max_tokens", "temperature")
                if k in body
            }
            for candidate in candidates:
                self.evidence.healthy()
                route = routes[candidate]
                attempted = pair_dict(candidate)
                attempt_id = str(uuid.uuid4())
                try:
                    key = self.state.secret(route["key_file"])
                    attestation_key = self.state.secret(route["attestation_file"])
                    require(not hmac.compare_digest(key, attestation_key))
                    result, served = upstream(
                        route, payload, attempt_id, key, attestation_key
                    )
                except Unavailable:
                    self.evidence.append(
                        request_id, scope, requested, attempted, None, "unavailable"
                    )
                    continue
                except Exception:
                    self.evidence.append(
                        request_id,
                        scope,
                        requested,
                        attempted,
                        None,
                        "upstream_rejected",
                    )
                    return 502, {"error": "upstream_rejected"}
                self.evidence.append(
                    request_id,
                    scope,
                    requested,
                    attempted,
                    served,
                    "success",
                    "hmac-sha256-trusted-adapter-v1",
                )
                result["id"] = request_id
                return 200, result
            return 502, {"error": "upstream_unavailable"}
        except Exception:
            return 503, {"error": "evidence_unavailable"}


class Handler(BaseHTTPRequestHandler):
    # No untrusted method/path/header/body/exception text on stdout or stderr.
    server_version = "CFLocal"
    sys_version = ""

    def setup(self):
        super().setup()
        self.connection.settimeout(TIMEOUT)

    def log_message(self, format, *args):
        pass

    def send_error(self, code, message=None, explain=None):
        self.reply(code, {"error": "request_denied"})

    def reply(self, status, value):
        raw = canonical(value)
        self.close_connection = True
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(raw)
        except (OSError, TimeoutError):
            pass

    def do_POST(self):
        allowed = {
            "host",
            "authorization",
            "content-type",
            "content-length",
            "accept",
            "accept-encoding",
            "user-agent",
            "connection",
        }
        names = [name.lower() for name in self.headers.keys()]
        valid = (
            self.path == "/v1/chat/completions"
            and set(names) <= allowed
            and len(names) == len(set(names))
            and self.headers.get("Accept-Encoding", "identity") == "identity"
            and self.headers.get("Content-Type") == "application/json"
        )
        raw = b""
        try:
            length = self.headers.get("Content-Length", "")
            require(re.fullmatch(r"[0-9]{1,5}", length) is not None)
            length = int(length)
            require(1 <= length <= MAX_BODY)
            require(valid)
            raw = self.rfile.read(length)
            valid = len(raw) == length
        except Exception:
            valid = False
        status, value = self.server.gateway.handle(
            raw, self.headers.get("Authorization"), valid
        )
        self.reply(status, value)


class Server(HTTPServer):
    def handle_error(self, request, client_address):
        # BaseServer would print tracebacks including third-party exceptions.
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--port", type=int, default=0)
    args = parser.parse_args()
    state = gateway = server = None
    try:
        require(0 <= args.port <= 65535)
        state = State(args.state_dir)
        gateway = Gateway(state)
        server = Server(("127.0.0.1", args.port), Handler)
        server.gateway = gateway
        print(
            "PASS inference-proxy loopback port=" + str(server.server_port), flush=True
        )
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    except Exception:
        print("FAIL inference-proxy: startup_or_runtime_refused", file=sys.stderr)
        return 1
    finally:
        if server is not None:
            server.server_close()
        if gateway is not None:
            gateway.evidence.close()
        if state is not None:
            state.close()


if __name__ == "__main__":
    sys.exit(main())
