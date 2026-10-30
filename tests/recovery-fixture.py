#!/usr/bin/env python3
"""Test-only recovery kernel for a caller-owned private local fixture.

No network transport, production URL parsing, credential resolution, provisioning,
backup, job execution or destructive cleanup. See specs/STORAGE.md.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


class RecoveryError(ValueError):
    pass


def digest(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("duplicate")
        result[key] = value
    return result


def read_regular(path, code, limit):
    try:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_size > limit:
            raise RecoveryError(code + "_type")
        return path.read_bytes()
    except FileNotFoundError:
        raise RecoveryError(code + "_missing") from None


def git(root, *args, check=True):
    # Allowlist environment: never inherit host Git config/credential commands.
    env = {
        "PATH": os.defpath,
        "HOME": str(root / "control"),
        "XDG_CONFIG_HOME": str(root / "control"),
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_ALLOW_PROTOCOL": "file",
        "LC_ALL": "C",
    }
    result = subprocess.run(
        [
            "git",
            "--no-optional-locks",
            "-c",
            "core.hooksPath=" + os.devnull,
            "-c",
            "init.templateDir=",
            *args,
        ],
        cwd=root,
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    if check and result.returncode != 0:
        raise RecoveryError("git_operation")
    return result


def validate(record):
    try:
        if set(record) != {
            "version",
            "repository",
            "commit",
            "dispatch_id",
            "artifact",
            "pending_dispatches",
            "unpublished_work",
        }:
            return False
        artifact = record["artifact"]
        pending = record["pending_dispatches"]
        return (
            type(record["version"]) is int
            and record["version"] == 1
            and record["repository"] == "fixture/origin"
            and isinstance(record["commit"], str)
            and re.fullmatch(r"[0-9a-f]{40}", record["commit"]) is not None
            and record["dispatch_id"] == "accepted-job"
            and type(artifact) is dict
            and set(artifact) == {"name", "sha256", "bytes"}
            and artifact["name"] == "gate.log"
            and digest(artifact["sha256"])
            and type(artifact["bytes"]) is int
            and 0 <= artifact["bytes"] <= 16 * 1024 * 1024
            and type(pending) is list
            and pending == ["pending-job"]
            and record["unpublished_work"] == "not-exported"
        )
    except (TypeError, KeyError):
        return False


def recover(root, metadata_pin, destination):
    # Destination is one fresh fixture basename, never a production node path.
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,63}", destination):
        raise RecoveryError("destination")
    if destination in {"control", "durable", "scratch"}:
        raise RecoveryError("destination")
    if not digest(metadata_pin):
        raise RecoveryError("trust_pin")
    raw = read_regular(root / "durable/accepted.json", "metadata", 65536)
    actual_metadata = hashlib.sha256(raw).hexdigest()
    if actual_metadata != metadata_pin:
        raise RecoveryError("metadata_integrity")
    try:
        record = json.loads(raw, object_pairs_hook=pairs)
        if not validate(record):
            raise ValueError("shape")
    except (ValueError, TypeError, UnicodeError):
        raise RecoveryError("metadata_schema") from None

    artifact = record["artifact"]
    payload = read_regular(
        root / "durable" / artifact["name"], "artifact", 16 * 1024 * 1024
    )
    actual = hashlib.sha256(payload).hexdigest()
    if actual != artifact["sha256"] or len(payload) != artifact["bytes"]:
        raise RecoveryError("artifact_integrity")
    origin = root / "durable/origin.git"
    commit = record["commit"]
    if git(
        root,
        "--git-dir",
        str(origin),
        "cat-file",
        "-e",
        commit + "^{commit}",
        check=False,
    ).returncode:
        raise RecoveryError("commit_missing")

    workspace = root / destination
    if workspace.exists() or workspace.is_symlink():
        # Never reset, fetch into, repair or overwrite an existing destination.
        if workspace.is_symlink() or not (workspace / ".git").is_dir():
            raise RecoveryError("workspace_mismatch")
        observed_origin = git(root, "-C", str(workspace), "remote", "get-url", "origin")
        head = git(root, "-C", str(workspace), "rev-parse", "HEAD")
        dirty = git(
            root, "-C", str(workspace), "status", "--porcelain", "--untracked-files=all"
        )
        if (
            observed_origin.stdout.strip() != str(origin)
            or head.stdout.strip() != commit
            or dirty.stdout
            or (workspace / ".git/objects/info/alternates").exists()
        ):
            raise RecoveryError("workspace_mismatch")
    else:
        git(
            root,
            "clone",
            "--no-local",
            "--no-hardlinks",
            "--no-checkout",
            "--template=",
            str(origin),
            str(workspace),
        )
        git(root, "-C", str(workspace), "checkout", "--detach", commit)
    head = git(root, "-C", str(workspace), "rev-parse", "HEAD").stdout.strip()
    if head != commit:
        raise RecoveryError("workspace_mismatch")
    return {
        "commit": head,
        "sha256": actual,
        "bytes": len(payload),
        "pending": {item: "unknown" for item in record["pending_dispatches"]},
        "unpublished_work": "unrecoverable",
    }


if __name__ == "__main__":
    try:
        if len(sys.argv) != 4:
            raise RecoveryError("arguments")
        print(
            json.dumps(
                recover(Path(sys.argv[1]), sys.argv[2], sys.argv[3]), sort_keys=True
            )
        )
    except RecoveryError as exc:
        print("FAIL recovery:" + str(exc), file=sys.stderr)
        sys.exit(1)
    except (OSError, subprocess.SubprocessError):
        print("FAIL recovery:fixture_io", file=sys.stderr)
        sys.exit(1)
