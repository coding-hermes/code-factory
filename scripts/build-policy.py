#!/usr/bin/env python3
"""Small local BUILD policy kernel, not a runner, sandbox or build launcher.

Only a trusted caller may choose context, cache root, expected digest and host
inventory. Serialize writers per private root. No network or package installs.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

TRUST = {"trusted", "untrusted"}
FIELDS = {
    "project",
    "repository",
    "trust",
    "ref",
    "runtime",
    "platform",
    "manager",
    "manager_version",
    "image_digest",
    "lock_digest",
    "build_digest",
    "cache_kind",
}
REQUESTS = {
    "key": {"context"},
    "put": {"context", "root", "source", "sha256", "job_trust"},
    "get": {"context", "root", "sha256"},
    "placement": {"weight", "observed_host", "control_host", "admitted_hosts"},
}


def digest(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ValueError("digest")
    return value


def cache_key(context):
    if not isinstance(context, dict) or set(context) != FIELDS:
        raise ValueError("context_fields")
    for value in context.values():
        if (
            not isinstance(value, str)
            or not value
            or value.strip() != value
            or any(ord(char) < 32 or ord(char) == 127 for char in value)
        ):
            raise ValueError("context_value")
    if context["trust"] not in TRUST:
        raise ValueError("context_trust")
    for field in ("image_digest", "lock_digest", "build_digest"):
        try:
            digest(context[field])
        except ValueError as exc:
            raise ValueError("context_digest") from exc
    identity = dict(context)
    encoded = json.dumps(
        identity, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )
    return "cf-build-v1/" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def no_symlinks(path):
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError("symlink")


def private_directory(path):
    no_symlinks(path)
    info = path.stat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_mode & 0o077
    ):
        raise ValueError("private_directory")


def regular_bytes(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError("regular_file")
    return path.read_bytes()


def verified(data, expected, reason):
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        raise ValueError(reason)
    return {"sha256": actual, "bytes": len(data)}


def cache_entry(root, key):
    root = Path(root)
    if not root.is_absolute() or ".." in root.parts:
        raise ValueError("root_absolute")
    no_symlinks(root)
    if not root.exists():
        raise ValueError("root_missing")
    private_directory(root)
    entry = root / key
    for directory in (entry.parent, entry):
        no_symlinks(directory)
        if directory.exists():
            private_directory(directory)
    return entry


def cache_get(context, root, sha256):
    key = cache_key(context)
    digest(sha256)
    entry = cache_entry(root, key)
    blob = entry / "blob"
    if not blob.exists() and not blob.is_symlink():
        return {"status": "MISS"}
    data = regular_bytes(blob)
    return {"status": "HIT", **verified(data, sha256, "entry_integrity")}


def cache_put(context, root, source, sha256, job_trust):
    key = cache_key(context)
    if job_trust not in TRUST or job_trust != context["trust"]:
        raise ValueError("trust_write_denied")
    digest(sha256)
    entry = cache_entry(root, key)
    data = regular_bytes(Path(source))
    details = verified(data, sha256, "source_integrity")
    existing = cache_get(context, root, sha256)
    if existing["status"] == "HIT":
        return {"status": "REUSE", **details}
    # Caller serializes writers; paths below the private root are digest-derived.
    entry.parent.mkdir(mode=0o700, exist_ok=True)
    entry.mkdir(mode=0o700, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=entry, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, entry / "blob")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    # Re-read published bytes rather than treating successful rename as evidence.
    return {
        "status": "STORED",
        **verified(regular_bytes(entry / "blob"), sha256, "entry_integrity"),
    }


def placement(weight, observed_host, control_host, admitted_hosts):
    if weight not in ("light", "heavy"):
        raise ValueError("weight")
    for host in (observed_host, control_host):
        if (
            not isinstance(host, str)
            or host == "unknown"
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", host)
        ):
            raise ValueError("identity")
    if (
        not isinstance(admitted_hosts, list)
        or not admitted_hosts
        or any(not isinstance(host, str) or not host for host in admitted_hosts)
    ):
        raise ValueError("inventory")
    if observed_host == control_host and weight == "heavy":
        raise ValueError("control_host")
    if observed_host != control_host and observed_host not in admitted_hosts:
        raise ValueError("not_admitted")
    return {"status": "ALLOW", "host": observed_host, "weight": weight}


def evaluate(operation, request):
    if operation not in REQUESTS:
        raise ValueError("operation")
    if not isinstance(request, dict) or set(request) != REQUESTS[operation]:
        raise ValueError("request_fields")
    if operation == "key":
        return {"key": cache_key(request["context"])}
    if operation == "placement":
        return placement(**request)
    if operation == "put":
        return cache_put(**request)
    return cache_get(**request)


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("operation_required")
        result = evaluate(sys.argv[1], json.load(sys.stdin))
    except (ValueError, TypeError, OSError) as exc:
        # No input bodies, credentials, paths or environment dumps in diagnostics.
        reason = (
            str(exc)
            if isinstance(exc, ValueError) and not isinstance(exc, json.JSONDecodeError)
            else type(exc).__name__
        )
        print("FAIL build-policy: " + reason, file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
