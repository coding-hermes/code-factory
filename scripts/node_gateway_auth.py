#!/usr/bin/env python3
"""node_gateway_auth.py — make a public bind legal on a node: ensure dashboard.basic_auth.

A Hermes gateway refuses to bind 0.0.0.0 without dashboard.basic_auth in ~/.hermes/config.yaml,
and no stage in the create path writes it (CF-150), so NODE: PASS is unreachable on a fresh
node. This adds the block when it is absent and leaves an existing one untouched.

  node_gateway_auth.py <config.yaml> <password-file> [<username>]

The password is generated on the node, written to <password-file> at mode 600, and NEVER
printed — stdout carries the fact and the paths, not the secret.

Exit 0 = the block is present (added now or already there); 1 = the file could not be read;
2 = the file already has a dashboard block that is NOT basic_auth (left untouched, named).
"""

import os
import secrets
import sys


def find_dashboard(lines: list) -> int:
    for i, line in enumerate(lines):
        if line.rstrip("\n") == "dashboard:" or line.startswith("dashboard:"):
            return i
    return -1


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
        block = "".join(lines[idx : idx + 8])
        if "basic_auth:" in block:
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

    password = secrets.token_urlsafe(24)
    os.makedirs(os.path.dirname(password_file) or ".", exist_ok=True)
    fd = os.open(password_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(password + "\n")
    os.chmod(password_file, 0o600)

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
    with open(tmp, "w") as fh:
        fh.writelines(lines)
    os.chmod(tmp, 0o600)
    os.replace(tmp, config)

    print(
        f"PASS  gateway_auth — added dashboard.basic_auth (user {username}) to {config}"
    )
    print(
        f"PASS  gateway_auth — password stored at {password_file}, mode 600 (not printed)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
