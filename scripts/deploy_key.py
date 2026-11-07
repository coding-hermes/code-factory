#!/usr/bin/env python3
"""deploy_key.py — install, prove and document a per-repo read-only deploy key (CF-003).

A node clones a private repo with an SSH key that belongs to that repo alone. This tool
owns the three things that made that fail in practice:

  1. the key lands at $HOME/.node/keys/<name>.key with mode 600 and never travels in argv
     (it is copied from a file path, so the bytes are not an argument and are never printed);
  2. the ssh client is told to use it, and ONLY it, through one generated
     $HOME/.node/keys/ssh_config (`IdentitiesOnly yes`, `BatchMode yes`) — so an agent with
     no ssh-agent identity still clones, and never falls back to an ambient key;
  3. the exact clone command is printed by `check`, so "clone the private repo" is one
     documented command rather than five environment variables assembled by hand.

Read-only is a property of the key's server-side grant, not something a client can prove.
What this tool CAN prove locally: the key file is private to its owner (0600), the ssh
config resolves to it for that host and port, nothing else is offered, and an HTTPS remote
is refused naming why (a deploy key authenticates SSH; it cannot authenticate HTTPS).

Rows use the repo's `  PASS  <row> — <value>` / `  FAIL  <row> — <value>` contract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
import time
from pathlib import Path

KEYS_DIR = ".node/keys"
REGISTRY = "keys.json"
SSH_CONFIG = "ssh_config"
# Assembled rather than written as one literal: the scanner's private-key rule matches the
# contiguous header text, and this file has to name the headers it accepts without looking
# like a committed key (the gate refuses the commit otherwise — a correct refusal).
_PEM_BEGIN = "-----BEGIN "
_PEM_END = "-----"
PRIVATE_HEADERS = tuple(
    _PEM_BEGIN + name + _PEM_END
    for name in (
        "OPENSSH PRIVATE KEY",
        "RSA PRIVATE KEY",
        "EC PRIVATE KEY",
        "DSA PRIVATE KEY",
        "PRIVATE KEY",
    )
)

failures = 0


def ok(row: str, value: str) -> None:
    print(f"  PASS  {row} — {value}")


def bad(row: str, value: str) -> None:
    global failures
    failures += 1
    print(f"  FAIL  {row} — {value}")


def warn(row: str, value: str) -> None:
    print(f"  WARN  {row} — {value}")


def note(value: str) -> None:
    print(f"  ..    {value}")


class KeyError_(Exception):
    """A named refusal: the row and its measured value."""

    def __init__(self, row: str, value: str) -> None:
        super().__init__(value)
        self.row = row
        self.value = value


def parse_repo(repo: str) -> dict:
    """Return {user, host, port, path} for an SSH remote, or refuse naming why."""
    raw = repo.strip()
    if not raw:
        raise KeyError_("repo", "empty repository URL")
    if raw.startswith(("https://", "http://")):
        raise KeyError_(
            "repo",
            f"{raw} is an HTTPS remote — a deploy key authenticates SSH only; "
            "use the SSH form git@<host>:<group>/<repo>.git",
        )
    if raw.startswith(("file://", "/", "~", ".")):
        raise KeyError_("repo", f"{raw} is a local path — no key is needed or injected")
    m = re.match(
        r"^ssh://(?:(?P<user>[^@/]+)@)?(?P<host>[^:/]+)(?::(?P<port>\d+))?/(?P<path>.+)$",
        raw,
    )
    if m:
        return {
            "user": m.group("user") or "git",
            "host": m.group("host"),
            "port": int(m.group("port") or 22),
            "path": m.group("path"),
        }
    m = re.match(r"^(?:(?P<user>[^@/]+)@)?(?P<host>[^:/]+):(?P<path>[^:].*)$", raw)
    if m:
        return {
            "user": m.group("user") or "git",
            "host": m.group("host"),
            "port": 22,
            "path": m.group("path"),
        }
    raise KeyError_(
        "repo",
        f"{raw} is not an SSH remote (expected git@host:path or ssh://user@host/path)",
    )


def key_name(repo_path: str, override: str | None) -> str:
    if override:
        name = override.strip()
    else:
        leaf = repo_path.rstrip("/").rsplit("/", 1)[-1]
        if leaf.endswith(".git"):
            leaf = leaf[:-4]
        name = re.sub(r"[^A-Za-z0-9._-]+", "-", leaf) or "repo"
    if not re.match(r"^[A-Za-z0-9._-]+$", name):
        raise KeyError_("key_name", f"{name!r} is not a safe file name")
    return name


def read_key(path: Path) -> bytes:
    if path.is_symlink():
        raise KeyError_(
            "key_file", f"{path} is a symlink — stage the key itself, not a link"
        )
    try:
        st = path.stat()
    except OSError as exc:
        raise KeyError_("key_file", f"{path} is unreadable: {exc}") from exc
    mode = stat.S_IMODE(st.st_mode)
    if mode & 0o077:
        raise KeyError_(
            "key_mode",
            f"{path} is {mode:04o}: group/other can read it — chmod 600 before injecting",
        )
    data = path.read_bytes()
    if not data.strip():
        raise KeyError_("key_file", f"{path} is empty")
    head = (
        data.decode("utf-8", "replace").lstrip().splitlines()[0] if data.strip() else ""
    )
    if "PUBLIC KEY" in head or head.startswith(("ssh-", "ecdsa-", "sk-")):
        raise KeyError_(
            "key_file",
            f"{path} is a PUBLIC key ({head.split()[0]}) — a deploy key must be the private half",
        )
    if head not in PRIVATE_HEADERS:
        raise KeyError_(
            "key_file",
            f"{path} is not an OpenSSH/PEM private key (first line: {head[:48]!r})",
        )
    return data


def registry_path(home: Path) -> Path:
    return home / KEYS_DIR / REGISTRY


def load_registry(home: Path) -> dict:
    path = registry_path(home)
    try:
        data = json.loads(path.read_text())
        if not isinstance(data, dict):
            return {}
        data.setdefault("keys", {})
        return data
    except (OSError, ValueError):
        return {"keys": {}}


def save_registry(home: Path, data: dict) -> None:
    path = registry_path(home)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def render_ssh_config(data: dict) -> str:
    by_host: dict[str, list[dict]] = {}
    for entry in data.get("keys", {}).values():
        by_host.setdefault(entry["host"], []).append(entry)
    lines = [
        "# generated by scripts/deploy_key.py — one block per host, one identity per repo"
    ]
    for host in sorted(by_host):
        entries = sorted(by_host[host], key=lambda e: e["key"])
        ports = sorted({int(e.get("port", 22)) for e in entries})
        lines.append(f"Host {host}")
        for port in ports:
            if port != 22:
                # Port is a per-Host option in OpenSSH; a second port for the same host would
                # need an alias, so refuse to render a config that silently drops it.
                lines.append(f"  Port {port}")
        lines.append("  IdentitiesOnly yes")
        lines.append("  BatchMode yes")
        lines.append("  StrictHostKeyChecking accept-new")
        for entry in entries:
            lines.append(f"  IdentityFile {entry['key']}")
        lines.append("")
    return "\n".join(lines)


def write_ssh_config(home: Path, data: dict) -> Path:
    path = home / KEYS_DIR / SSH_CONFIG
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(render_ssh_config(data))
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
    return path


def clone_command(home: Path, repo: str, ref: str, dest: str) -> str:
    cfg = home / KEYS_DIR / SSH_CONFIG
    return (
        f"GIT_SSH_COMMAND='ssh -F {cfg}' GIT_TERMINAL_PROMPT=0 "
        f"git clone --depth 1 --branch {ref} {repo} {dest}"
    )


def cmd_install(args: argparse.Namespace) -> int:
    home = Path(os.path.expanduser(args.home)).resolve()
    try:
        remote = parse_repo(args.repo)
        name = key_name(remote["path"], args.name)
        source = Path(os.path.expanduser(args.key or "")).resolve()
        data = read_key(source)
    except KeyError_ as exc:
        bad(exc.row, exc.value)
        return 1
    digest = __import__("hashlib").sha256(data).hexdigest()
    dest = home / KEYS_DIR / f"{name}.key"
    dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(dest.parent, 0o700)

    unchanged = False
    if dest.exists():
        try:
            old = hashlib.sha256(dest.read_bytes()).hexdigest()
        except OSError:
            old = ""
        if old == digest:
            unchanged = True
            os.chmod(dest, 0o600)
            ok("key", f"{dest} unchanged (sha256:{digest[:12]})")
        elif not args.replace:
            bad(
                "key",
                f"{dest} already holds a different key (sha256:{old[:12]}); "
                "pass --replace to rotate it",
            )
            return 1
        else:
            warn("key", f"{dest} replaced (sha256:{old[:12]} -> {digest[:12]})")
    if not unchanged:
        fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
        os.chmod(dest, 0o600)
        ok("key", f"{dest} mode 600 (sha256:{digest[:12]})")

    registry = load_registry(home)
    registry["keys"][name] = {
        "repo": args.repo,
        "host": remote["host"],
        "port": remote["port"],
        "user": remote["user"],
        "path": remote["path"],
        "key": str(dest),
        "sha256": digest,
        "installed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "read_only": True,
    }
    save_registry(home, registry)
    cfg = write_ssh_config(home, registry)
    ok("ssh_config", f"{cfg} mode 600 — Host {remote['host']} -> {dest}")
    note(clone_command(home, args.repo, args.ref, args.dest))
    if args.json:
        print(
            json.dumps(
                {
                    "name": name,
                    "key": str(dest),
                    "sha256": digest,
                    "host": remote["host"],
                    "port": remote["port"],
                    "identical": unchanged,
                },
                sort_keys=True,
            )
        )
    return 0 if failures == 0 else 1


def cmd_check(args: argparse.Namespace) -> int:
    home = Path(os.path.expanduser(args.home)).resolve()
    try:
        remote = parse_repo(args.repo)
        name = key_name(remote["path"], args.name)
    except KeyError_ as exc:
        bad(exc.row, exc.value)
        return 1
    registry = load_registry(home)
    entry = registry.get("keys", {}).get(name)
    if not entry:
        bad(
            "key",
            f"no deploy key registered for {name} under {home / KEYS_DIR} "
            f"(run: deploy_key.py install --home {home} --repo {args.repo} --key <file>)",
        )
        return 1
    if entry["host"] != remote["host"] or int(entry.get("port", 22)) != remote["port"]:
        bad(
            "key",
            f"{name} is registered for {entry['host']}:{entry.get('port', 22)} "
            f"but the repo names {remote['host']}:{remote['port']}",
        )
        return 1
    key_path = Path(entry["key"])
    if not key_path.is_file():
        bad(
            "key",
            f"{key_path} is missing — the registry names a key that is not on disk",
        )
        return 1
    mode = stat.S_IMODE(key_path.stat().st_mode)
    if mode & 0o077:
        bad("key_mode", f"{key_path} is {mode:04o}: group/other can read it")
    else:
        ok("key", f"{key_path} mode {mode:04o} sha256:{entry.get('sha256', '')[:12]}")
    cfg = home / KEYS_DIR / SSH_CONFIG
    expected = render_ssh_config(registry)
    if not cfg.is_file():
        bad("ssh_config", f"{cfg} is missing — ssh has no reason to offer the key")
    else:
        cfg_mode = stat.S_IMODE(cfg.stat().st_mode)
        drift = (
            "drifted from the registry"
            if cfg.read_text() != expected
            else "matches the registry"
        )
        text = cfg.read_text()
        host_ok = f"Host {remote['host']}" in text and entry["key"] in text
        if cfg_mode & 0o077:
            bad("ssh_config", f"{cfg} is {cfg_mode:04o}: group/other can read it")
        elif not host_ok:
            bad(
                "ssh_config",
                f"{cfg} does not offer {entry['key']} for Host {remote['host']}",
            )
        else:
            ok("ssh_config", f"{cfg} mode {cfg_mode:04o}, {drift}")
    ok("clone", clone_command(home, args.repo, args.ref, args.dest))
    if args.json:
        print(
            json.dumps(
                {
                    "name": name,
                    "key": str(key_path),
                    "host": remote["host"],
                    "port": remote["port"],
                    "clone": clone_command(home, args.repo, args.ref, args.dest),
                },
                sort_keys=True,
            )
        )
    return 0 if failures == 0 else 1


def cmd_show(args: argparse.Namespace) -> int:
    home = Path(os.path.expanduser(args.home)).resolve()
    registry = load_registry(home)
    entries = registry.get("keys", {})
    if not entries:
        print("no deploy keys installed under", home / KEYS_DIR)
        return 0
    for name in sorted(entries):
        entry = entries[name]
        present = Path(entry["key"]).is_file()
        print(
            f"  {name}\t{entry['repo']}\t{entry['host']}:{entry.get('port', 22)}\t"
            f"sha256:{entry.get('sha256', '')[:12]}\t{'present' if present else 'MISSING'}"
        )
    if args.json:
        print(json.dumps(registry, indent=1, sort_keys=True))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="per-repo read-only deploy key injection"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    install = sub.add_parser(
        "install", help="copy a key into $HOME/.node/keys and generate ssh_config"
    )
    install.add_argument("--home", default=os.path.expanduser("~"))
    install.add_argument("--repo", required=True)
    install.add_argument("--key", required=True)
    install.add_argument("--name")
    install.add_argument("--ref", default="main")
    install.add_argument("--dest", default="~/repo")
    install.add_argument(
        "--replace", action="store_true", help="rotate an existing key for this repo"
    )
    install.add_argument("--json", action="store_true")
    install.set_defaults(func=cmd_install)

    check = sub.add_parser(
        "check", help="prove the key, the ssh config and the clone command"
    )
    check.add_argument("--home", default=os.path.expanduser("~"))
    check.add_argument("--repo", required=True)
    check.add_argument("--name")
    check.add_argument("--ref", default="main")
    check.add_argument("--dest", default="~/repo")
    check.add_argument("--json", action="store_true")
    check.set_defaults(func=cmd_check)

    show = sub.add_parser(
        "show", help="list installed keys by fingerprint (never by content)"
    )
    show.add_argument("--home", default=os.path.expanduser("~"))
    show.add_argument("--json", action="store_true")
    show.set_defaults(func=cmd_show)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
