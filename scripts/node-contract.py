#!/usr/bin/env python3
"""Narrow node-input, manifest and artifact filesystem contract (Linux nodes)."""

import base64
import hashlib
import json
import os
import re
import stat
import sys
import tempfile

IDENT = r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}"
SEGMENT = r"[A-Za-z0-9][A-Za-z0-9_-]*"
LABEL = r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
HOST = rf"{LABEL}(?:\.{LABEL})*"
REPO = rf"(?:https://{HOST}/{SEGMENT}/{SEGMENT}(?:\.git)?|git@{HOST}:{SEGMENT}/{SEGMENT}(?:\.git)?)"
MAX_BYTES = 16 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def identity(args):
    project, repo, harness, node, ref, port, bus_id, bus_base = args
    require(re.fullmatch(IDENT, project), "invalid project")
    require(
        re.fullmatch(REPO, repo),
        "invalid repo: use https://HOST/OWNER/REPO or git@HOST:OWNER/REPO",
    )
    require(
        harness == "hermes",
        "unsupported harness: only hermes is supported for provisioning",
    )
    require(re.fullmatch(IDENT, node), "invalid node id")
    require(re.fullmatch(rf"{SEGMENT}(?:/{SEGMENT})*", ref), "invalid ref")
    require(
        port.isascii() and port.isdigit() and 1 <= int(port) <= 65535, "invalid port"
    )
    return {
        "node_id": node,
        "project": project,
        "repo": {
            "origin": repo,
            "ref": ref,
            "path": os.path.join(os.environ["HOME"], "repo"),
        },
        "harness": {"name": harness, "port": int(port)},
        "bus": {"agent_id": bus_id, "base": bus_base},
    }


def artifact_path(path, dispatch):
    if path == "~/.node/node.json":
        return [".node", "node.json"]
    require(
        re.fullmatch(IDENT, dispatch), "dispatch artifact requires valid --dispatch-id"
    )
    prefix = f"~/.node/jobs/{dispatch}/artifacts/"
    require(path.startswith(prefix), "artifact outside dispatch/manifest contract")
    name = path[len(prefix) :]
    require(
        re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", name),
        "invalid artifact filename",
    )
    require(".." not in name, "artifact traversal denied")
    require(
        not re.search(r"config|secret|credential|token|key|env", name, re.I),
        "config/secret artifact denied",
    )
    return [".node", "jobs", dispatch, "artifacts", name]


def read_beneath(parts):
    # Keep directory descriptors open while walking; never resolve an untrusted link.
    fd = os.open(os.environ["HOME"], os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in parts[:-1]:
            child = os.open(
                part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd
            )
            os.close(fd)
            fd = child
        file_fd = os.open(
            parts[-1], os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW, dir_fd=fd
        )
        with os.fdopen(file_fd, "rb") as stream:
            info = os.fstat(stream.fileno())
            require(
                stat.S_ISREG(info.st_mode) and info.st_nlink == 1,
                "artifact must be regular, not linked",
            )
            require(info.st_size <= MAX_BYTES, "artifact exceeds 16 MiB")
            data = stream.read(MAX_BYTES + 1)
            require(len(data) <= MAX_BYTES, "artifact grew past 16 MiB")
            return data
    finally:
        os.close(fd)


def manifest_check(expected):
    path = os.path.join(os.environ["HOME"], ".node", "node.json")
    require(
        not os.path.islink(os.path.dirname(path)),
        "manifest state directory is a symlink",
    )
    if not os.path.lexists(path):
        return False
    data = json.loads(read_beneath([".node", "node.json"]))
    for key in ("node_id", "project", "bus"):
        require(data.get(key) == expected[key], f"manifest identity mismatch: {key}")
    for key, fields in [
        ("repo", ("origin", "ref", "path")),
        ("harness", ("name", "port")),
    ]:
        require(isinstance(data.get(key), dict), f"invalid manifest {key}")
        for field in fields:
            require(
                data[key].get(field) == expected[key][field],
                f"manifest identity mismatch: {key}.{field}",
            )
    return True


def main():
    action, *args = sys.argv[1:]
    if action == "validate":
        identity(args)
    elif action == "create-input":
        identity(args[:8])
        server, ttl = args[8:]
        require(re.fullmatch(IDENT, server), "invalid or missing server")
        require(re.fullmatch(r"[1-9][0-9]*[mhd]", ttl), "invalid ttl")
    elif action == "verify-input":
        agent, server, port = args
        require(
            re.fullmatch(IDENT, agent) and re.fullmatch(IDENT, server),
            "invalid agent/server",
        )
        require(
            port.isascii() and port.isdigit() and 1 <= int(port) <= 65535,
            "invalid port",
        )
    elif action == "artifact-path":
        artifact_path(*args)
    elif action == "artifact-read":
        data = read_beneath(artifact_path(*args))
        print(
            json.dumps(
                {
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "data": base64.b64encode(data).decode("ascii"),
                }
            )
        )
    elif action == "artifact-verify":
        with open(args[0], encoding="utf-8") as stream:
            result = json.load(stream)
        data = base64.b64decode(result["data"], validate=True)
        digest = hashlib.sha256(data).hexdigest()
        require(digest == result["sha256"], "artifact digest mismatch")
        print(digest)
    elif action in ("manifest-check", "manifest-write"):
        expected = identity(args[:8])
        exists = manifest_check(expected)
        if action == "manifest-write" and not exists:
            import time

            expected["harness"]["version"] = args[8]
            expected["created_by"] = "project-node.sh v1"
            expected["created_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            directory = os.path.join(os.environ["HOME"], ".node")
            fd, temp = tempfile.mkstemp(prefix=".manifest-", dir=directory)
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as stream:
                    json.dump(expected, stream, indent=1)
                    stream.flush()
                    os.fsync(stream.fileno())
                # Publish without replacing a concurrently created identity.
                os.link(
                    temp, os.path.join(directory, "node.json"), follow_symlinks=False
                )
            finally:
                os.unlink(temp)
    else:
        raise ValueError("unknown contract action")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"node contract refused: {error}", file=sys.stderr)
        sys.exit(1)
