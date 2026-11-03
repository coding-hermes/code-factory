#!/usr/bin/env python3
"""lane_target.py — one parser for every place a lane's workdir can live.

A lane's `workdir` is not always a local directory. It can be a remote path
addressed the way people actually address remote paths:

    /home/kara/code-factory                  local absolute path
    ~/work/code-factory                      local, home-relative
    local:/home/kara/code-factory            local, explicitly tagged
    builder@node-01:/home/agent/code-factory scp/rsync style (user, host, path)
    ssh://builder@node-01:2222/srv/cf       URL style with port
    sftp://builder@node-01/srv/cf           sftp URL
    ftp://deploy@mirror.example/pub/cf      ftp URL
    bunker://code-factory-worker/srv/cf     bunker agent identity + path

Two jobs, both falsifiable without a network:

  parse   structurally validate a target and emit its components as JSON.
  verify  for a LOCAL target: check it is a real git checkout whose top level is
          not the operator's home directory (the "stand-in locator" defect that
          made five satellites read the wrong board). For a REMOTE target there is
          nothing to check locally, so verification is explicitly
          `remote-structural-only` and must be requested with --allow-remote.

Exit codes: 0 ok, 2 unparseable/invalid, 3 remote verification not permitted,
4 local target failed verification.

This module is stdlib-only and never makes a network call.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from typing import Optional

LOCAL_SCHEMES = {"local", "file"}
REMOTE_SCHEMES = {"ssh", "sftp", "ftp", "ftps", "rsync", "bunker"}

# Hostname labels: letters/digits/hyphen, no leading/trailing hyphen. Also allow
# IPv4 and bracketed IPv6.
_HOST_RE = re.compile(r"^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*$")
_IPV4_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")
_USER_RE = re.compile(r"^[A-Za-z0-9._][A-Za-z0-9._-]{0,62}$")
_SCP_RE = re.compile(r"^(?P<user>[^@/\s]+)@(?P<host>[^:/\s]+):(?P<path>.+)$")


class TargetError(ValueError):
    """Raised for a target that cannot be parsed or is structurally invalid."""


@dataclass
class Target:
    raw: str
    kind: str  # "local" or "remote"
    scheme: str  # local, file, ssh, sftp, ftp, ftps, rsync, bunker
    path: str
    user: Optional[str] = None
    host: Optional[str] = None
    port: Optional[int] = None
    agent: Optional[str] = None  # bunker agent identity

    @property
    def is_local(self) -> bool:
        return self.kind == "local"

    def display(self) -> str:
        if self.is_local:
            return self.path
        if self.agent:
            return f"bunker://{self.agent}{self.path}"
        cred = f"{self.user}@" if self.user else ""
        port = f":{self.port}" if self.port else ""
        return f"{self.scheme}://{cred}{self.host}{port}{self.path}"


def _check_host(host: str) -> str:
    if not host or len(host) > 253:
        raise TargetError("host is empty or longer than 253 characters")
    if host.startswith("[") and host.endswith("]"):  # bracketed IPv6
        return host
    if _IPV4_RE.match(host):
        return host
    if not _HOST_RE.match(host):
        raise TargetError(f"invalid host: {host!r}")
    return host


def _check_user(user: str) -> str:
    if not _USER_RE.match(user):
        raise TargetError(f"invalid user: {user!r}")
    return user


def _check_port(port: str) -> int:
    if not port.isdigit() or not (0 < int(port) < 65536):
        raise TargetError(f"invalid port: {port!r} (expected 1-65535)")
    return int(port)


def _check_remote_path(path: str) -> str:
    if not path or path in ("/", "~", "~/"):
        raise TargetError("remote target needs a path below the host, e.g. /srv/code-factory")
    if any(ch in path for ch in "\x00\n\r\"'`"):
        raise TargetError("remote path contains control characters or quotes")
    if not path.startswith("/"):
        path = "/" + path
    return path


def _check_local_path(path: str) -> str:
    if not path:
        raise TargetError("local target needs a path")
    if any(ch in path for ch in "\x00\n\r"):
        raise TargetError("local path contains control characters")
    expanded = os.path.expanduser(path)
    if not os.path.isabs(expanded):
        raise TargetError(
            f"local target must be absolute or ~-relative, got {path!r} "
            "(a relative workdir resolves differently per lane cwd)"
        )
    return os.path.normpath(expanded)


def parse(raw: str) -> Target:
    """Parse one target string into a Target, or raise TargetError."""
    if raw is None:
        raise TargetError("target is null")
    text = raw.strip()
    if not text:
        raise TargetError("target is empty")
    if any(ch in text for ch in "\n\r\x00"):
        raise TargetError("target contains a newline or NUL")

    if "://" in text:
        scheme, rest = text.split("://", 1)
        scheme = scheme.lower()
        if scheme in LOCAL_SCHEMES:
            return Target(raw=raw, kind="local", scheme=scheme, path=_check_local_path(rest))
        if scheme not in REMOTE_SCHEMES:
            raise TargetError(
                f"unsupported scheme {scheme!r}; expected local/file/ssh/sftp/ftp/rsync/bunker"
            )
        if scheme == "bunker":
            agent, _, path = rest.partition("/")
            if not agent:
                raise TargetError("bunker target needs an agent name: bunker://<agent>/<path>")
            if not _USER_RE.match(agent):
                raise TargetError(f"invalid bunker agent: {agent!r}")
            return Target(
                raw=raw, kind="remote", scheme=scheme, agent=agent, path=_check_remote_path("/" + path)
            )
        creds, _, path = rest.partition("/")
        user = None
        port = None
        if "@" in creds:
            user, _, creds = creds.rpartition("@")
            user = _check_user(user)
        if ":" in creds:
            creds, _, port_s = creds.partition(":")
            port = _check_port(port_s)
        host = _check_host(creds)
        return Target(
            raw=raw,
            kind="remote",
            scheme=scheme,
            path=_check_remote_path("/" + path),
            user=user,
            host=host,
            port=port,
        )

    if text.startswith(("/", "~")):
        return Target(raw=raw, kind="local", scheme="local", path=_check_local_path(text))
    if text.startswith("local:"):
        return Target(
            raw=raw, kind="local", scheme="local", path=_check_local_path(text[len("local:"):])
        )

    m = _SCP_RE.match(text)
    if m:
        return Target(
            raw=raw,
            kind="remote",
            scheme="ssh",
            user=_check_user(m.group("user")),
            host=_check_host(m.group("host")),
            path=_check_remote_path(m.group("path")),
        )

    raise TargetError(
        f"cannot classify target {raw!r}: use an absolute path, ~/path, local:<path>, "
        "user@host:/path, <scheme>://[user@]host[:port]/path, or bunker://<agent>/path"
    )


def _git(root: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", root, *args], capture_output=True, text=True, timeout=30, check=False
    )


def verify_local(path: str, home: Optional[str] = None) -> dict:
    """Prove a local target is a usable project checkout, not a parent repo."""
    home = home or os.path.expanduser("~")
    result = {"path": path, "exists": os.path.isdir(path), "checks": [], "ok": False}

    def add(name: str, ok: bool, value: str) -> None:
        result["checks"].append({"check": name, "ok": ok, "value": value})

    if not result["exists"]:
        add("exists", False, "directory does not exist")
        return result
    add("exists", True, path)

    top = _git(path, "rev-parse", "--show-toplevel")
    toplevel = top.stdout.strip() if top.returncode == 0 else ""
    add("git_toplevel", bool(toplevel), toplevel or top.stderr.strip()[:200])
    if not toplevel:
        return result

    resolved = os.path.realpath(toplevel)
    home_real = os.path.realpath(home)
    # The stand-in defect: a workdir inside $HOME whose git top level IS $HOME.
    add(
        "not_home_repo",
        resolved != home_real,
        "top level is the home directory" if resolved == home_real else resolved,
    )
    add("toplevel_matches_target", resolved == os.path.realpath(path), resolved)

    remotes = _git(path, "remote")
    names = [n for n in remotes.stdout.split() if n]
    urls = {}
    for name in names:
        got = _git(path, "remote", "get-url", name)
        if got.returncode == 0:
            urls[name] = got.stdout.strip()
    add("has_remote", bool(urls), json.dumps(urls, sort_keys=True) if urls else "no remote")

    head = _git(path, "rev-parse", "--abbrev-ref", "HEAD")
    branch = head.stdout.strip() if head.returncode == 0 else ""
    add("attached_branch", branch not in ("", "HEAD"), branch or "detached or unknown")

    result["ok"] = all(c["ok"] for c in result["checks"])
    result["remotes"] = urls
    result["branch"] = branch
    return result


def verify_remote(target: Target, allow_remote: bool) -> dict:
    if not allow_remote:
        raise PermissionError(
            f"target {target.display()} is remote; local verification is impossible. "
            "Re-run with --allow-remote to record it as remote-structural-only."
        )
    return {
        "resolved": target.display(),
        "kind": "remote",
        "scheme": target.scheme,
        "user": target.user,
        "host": target.host,
        "port": target.port,
        "agent": target.agent,
        "path": target.path,
        "verified": "remote-structural-only",
        "ok": True,
        "note": "address is structurally valid; reachability and existence are NOT checked here",
    }


def verify_bunker(target: Target, server: Optional[str] = None, timeout: int = 60) -> dict:
    """Prove a bunker:// target exists by asking the agent itself.

    A bunker target is only meaningful if the agent is reachable and the path is
    really inside it. That is checkable without mounting anything:
    `bunker exec <agent> -- sh -lc 'echo $HOME; test -d <path>'`.
    """
    if target.scheme != "bunker" or not target.agent:
        raise TargetError("verify_bunker needs a bunker://<agent>/<path> target")

    cmd = ["bunker"]
    if server:
        cmd += ["--server", server]
    cmd += [
        "exec",
        target.agent,
        "--",
        "sh",
        "-lc",
        f'echo "HOME=$HOME"; if [ -d "{target.path}" ]; then echo "PATH_EXISTS=1"; else echo "PATH_EXISTS=0"; fi',
    ]
    result = {
        "resolved": target.display(),
        "kind": "remote",
        "scheme": "bunker",
        "agent": target.agent,
        "path": target.path,
        "verified": "bunker-exec",
        "checks": [],
        "ok": False,
    }

    def add(name: str, ok: bool, value: str) -> None:
        result["checks"].append({"check": name, "ok": ok, "value": value})

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
    except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
        add("agent_reachable", False, f"{type(exc).__name__}: {exc}")
        return result

    out = f"{proc.stdout}\n{proc.stderr}"
    add("bunker_cli", proc.returncode == 0, f"exit={proc.returncode}")

    home = ""
    for line in proc.stdout.splitlines():
        if line.startswith("HOME="):
            home = line.split("=", 1)[1].strip()
    add("agent_reachable", bool(home), home or out.strip()[:200])

    exists = "PATH_EXISTS=1" in proc.stdout
    add("path_exists", exists, f"{target.path} inside {target.agent}")

    if home:
        result["agent_home"] = home
        result["resolved"] = f"bunker://{target.agent}{target.path}"
    result["ok"] = all(c["ok"] for c in result["checks"])
    return result


def verify(
    target: Target,
    allow_remote: bool,
    home: Optional[str] = None,
    exec_bunker: bool = False,
    bunker_server: Optional[str] = None,
) -> dict:
    if target.is_local:
        out = verify_local(target.path, home=home)
        out["resolved"] = target.display()
        out["verified"] = "local"
        return out
    if exec_bunker and target.scheme == "bunker":
        return verify_bunker(target, server=bunker_server)
    return verify_remote(target, allow_remote)


def scan(projects_jsonl: str, allow_remote: bool, home: Optional[str] = None) -> dict:
    rows = []
    bad = 0
    with open(projects_jsonl, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                rows.append({"line": lineno, "ok": False, "error": f"invalid JSON: {exc}"})
                bad += 1
                continue
            name = row.get("name") or row.get("id") or f"line{lineno}"
            workdir = row.get("workdir")
            try:
                t = parse(workdir)
                out = verify(t, allow_remote=allow_remote, home=home)
                ok = bool(out.get("ok"))
            except (TargetError, PermissionError) as exc:
                out = {"resolved": workdir, "ok": False, "error": str(exc)}
                ok = False
            rows.append({"line": lineno, "name": name, "ok": ok, "target": out})
            bad += 0 if ok else 1
    return {"file": projects_jsonl, "rows": rows, "bad": bad, "ok": bad == 0}


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(description="parse and verify lane workdir targets")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("parse", help="parse one target, emit JSON")
    p.add_argument("target")

    v = sub.add_parser("verify", help="verify one target")
    v.add_argument("target")
    v.add_argument("--allow-remote", action="store_true")
    v.add_argument("--exec-bunker", action="store_true")
    v.add_argument("--bunker-server", default=None)
    v.add_argument("--home", default=None)

    s = sub.add_parser("scan", help="verify every workdir in a projects JSONL")
    s.add_argument("file")
    s.add_argument("--allow-remote", action="store_true")
    s.add_argument("--exec-bunker", action="store_true")
    s.add_argument("--bunker-server", default=None)
    s.add_argument("--home", default=None)

    p2 = sub.add_parser(
        "plan", help="emit bunker:// targets for every lane in a JSONL (writes nothing)"
    )
    p2.add_argument("file")
    p2.add_argument("--agent", required=True, help="bunker agent id that hosts the lane")
    p2.add_argument("--server", default=None, help="bunker server name (needed to resolve the agent home)")
    p2.add_argument("--suffix", default="/repo", help="path inside the agent home (default /repo, per specs/NODE.md)")
    p2.add_argument("--path", default=None, help="explicit in-agent path (skips home resolution)")
    p2.add_argument("--prefix", default=None, help="lane-name prefix to keep (e.g. code-factory)")

    a = ap.parse_args(argv)
    try:
        if a.cmd == "parse":
            print(json.dumps(asdict(parse(a.target)), indent=2))
            return 0
        if a.cmd == "verify":
            t = parse(a.target)
            out = verify(
                t,
                allow_remote=a.allow_remote,
                home=a.home,
                exec_bunker=a.exec_bunker,
                bunker_server=a.bunker_server,
            )
            print(json.dumps(out, indent=2))
            return 0 if out.get("ok") else 4
        if a.cmd == "scan":
            out = scan(a.file, allow_remote=a.allow_remote, home=a.home)
            print(json.dumps(out, indent=2))
            return 0 if out["ok"] else 4
        plan = []
        in_path = a.path
        if in_path is None:
            # Resolve the agent's real home instead of guessing a path: an agent's
            # home is /home/bunker-<id> today, which a template silently mis-guesses.
            probe = verify_bunker(
                Target(raw=f"bunker://{a.agent}/", kind="remote", scheme="bunker",
                       path="/", agent=a.agent),
                server=a.server,
            )
            home = probe.get("agent_home") or ""
            if not home:
                raise TargetError(
                    f"cannot resolve the home of agent {a.agent!r}; pass --server, or --path explicitly"
                )
            in_path = home.rstrip("/") + a.suffix
        with open(a.file, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                row = json.loads(line)
                name = row.get("name") or row.get("id") or ""
                if a.prefix and not name.startswith(a.prefix):
                    continue
                target = f"bunker://{a.agent}{in_path}"
                plan.append({"name": name, "workdir": target, "parsed": asdict(parse(target))})
        print(json.dumps(plan, indent=2))
        return 0
    except TargetError as exc:
        print(f"FAIL lane-target: {exc}", file=sys.stderr)
        return 2
    except PermissionError as exc:
        print(f"FAIL lane-target: {exc}", file=sys.stderr)
        return 3
    except FileNotFoundError as exc:
        print(f"FAIL lane-target: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
