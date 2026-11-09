#!/usr/bin/env python3
"""node_gateway_auth.py — make a public bind legal on a node: ensure dashboard.basic_auth.

A Hermes gateway refuses to bind 0.0.0.0 without dashboard.basic_auth in ~/.hermes/config.yaml,
and no stage in the create path writes it (CF-150), so NODE: PASS is unreachable on a fresh
node. This adds the block when it is absent and leaves an existing one untouched.

  node_gateway_auth.py <config.yaml> <password-file> [<username>]

The password is generated on the node, written to <password-file> at mode 600, and NEVER
printed — stdout carries the fact and the paths, not the secret. A freshly created node has no
~/.hermes yet (the adapter that owns it runs later in the same layer), so the config's parent
directory is created here, mode 700, when it is absent.

Exit 0 = the block is present (added now or already there); 1 = the config could not be read, or
its directory could not be created / the file could not be written; 2 = the file already has a
dashboard block that is NOT basic_auth (left untouched, named).

Presence is decided structurally, not by proximity: the dashboard block is the run of indented,
blank and comment lines that follows `dashboard:`, and a `basic_auth:` counts only when it is
itself indented — nested under `dashboard:` — so a sibling top-level key's `basic_auth:` is not
protection, and a nested one is found however far down the block it sits.
"""

import os
import secrets
import sys


def find_dashboard(lines: list) -> int:
    for i, line in enumerate(lines):
        if line.rstrip("\n") == "dashboard:" or line.startswith("dashboard:"):
            return i
    return -1


def dashboard_block_end(lines: list, idx: int) -> int:
    """Index just past the `dashboard:` block: its indented, blank and comment lines.

    A block ends at the first line that is non-blank, not a comment, and starts at column 0 — that
    line is a sibling (or the next) top-level key, not a child of `dashboard:`. Comments and blank
    lines never end it: the consumer gate strips comments before it parses, so a comment between
    the last key and the next top-level key is not a block boundary.
    """
    end = idx + 1
    while end < len(lines):
        content = lines[end].rstrip("\n")
        stripped = content.strip()
        if not stripped or stripped.startswith("#") or content[0] in " \t":
            end += 1
            continue
        break
    return end


def has_nested_basic_auth(lines: list, idx: int) -> bool:
    """True when an indented `basic_auth:` line sits inside the `dashboard:` block.

    Indentation is what makes it the dashboard's child: a `basic_auth:` at column 0 is a top-level
    key of its own, and one belonging to a sibling top-level key lies outside the block entirely.
    """
    for raw in lines[idx + 1 : dashboard_block_end(lines, idx)]:
        content = raw.rstrip("\n")
        stripped = content.lstrip()
        if stripped.startswith("basic_auth:") and len(content) != len(stripped):
            return True
    return False


def main(argv: list) -> int:
    if len(argv) < 2:
        print(
            "usage: node_gateway_auth.py <config.yaml> <password-file> [username]",
            file=sys.stderr,
        )
        return 2
    config, password_file = argv[0], argv[1]
    username = argv[2] if len(argv) > 2 else "node"

    try:
        with open(config) as fh:
            lines = fh.readlines()
    except FileNotFoundError:
        lines = []
    except OSError as exc:
        print(f"FAIL  gateway_auth — cannot read {config} ({exc})", file=sys.stderr)
        return 1

    idx = find_dashboard(lines)
    if idx >= 0:
        if has_nested_basic_auth(lines, idx):
            print(
                f"PASS  gateway_auth — dashboard.basic_auth already present in {config}"
            )
            return 0
        print(
            f"FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block without basic_auth; "
            "left untouched (a human must reconcile it)",
            file=sys.stderr,
        )
        return 2

    # CF-388: on a freshly created node ~/.hermes does not exist yet — the harness adapter that
    # creates it runs LATER in the same layer — so the config's parent is this writer's
    # precondition, not the caller's. 0700 because that directory holds the gateway credential.
    # Nothing is created when the block is already present (the early return above), so a re-run
    # still changes nothing; a failure here is named and exits nonzero rather than escaping as a
    # traceback, because the caller's row would then report a staging failure with no reason.
    config_dir = os.path.dirname(config)
    if config_dir:
        try:
            os.makedirs(config_dir, mode=0o700, exist_ok=True)
        except OSError as exc:
            print(
                f"FAIL  gateway_auth — cannot create {config_dir} ({exc})",
                file=sys.stderr,
            )
            return 1

    password = secrets.token_urlsafe(24)
    try:
        os.makedirs(os.path.dirname(password_file) or ".", exist_ok=True)
        fd = os.open(password_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as fh:
            fh.write(password + "\n")
        os.chmod(password_file, 0o600)
    except OSError as exc:
        print(
            f"FAIL  gateway_auth — cannot write {password_file} ({exc})",
            file=sys.stderr,
        )
        return 1

    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines += [
        "\n",
        "dashboard:\n",
        "  basic_auth:\n",
        f"    username: {username}\n",
        f"    password: {password}\n",
    ]
    tmp = config + ".cf-tmp"
    try:
        with open(tmp, "w") as fh:
            fh.writelines(lines)
        os.chmod(tmp, 0o600)
        os.replace(tmp, config)
    except OSError as exc:
        print(
            f"FAIL  gateway_auth — cannot write {config} ({exc})",
            file=sys.stderr,
        )
        return 1

    print(
        f"PASS  gateway_auth — added dashboard.basic_auth (user {username}) to {config}"
    )
    print(
        f"PASS  gateway_auth — password stored at {password_file}, mode 600 (not printed)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
