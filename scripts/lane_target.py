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

Checks, all falsifiable without a network:

  repo-url  validate project-row repo_url roots (one string or --row JSON).
            Local roots must match git's top level and have an observable HEAD.

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
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from typing import Optional

LOCAL_SCHEMES = {"local", "file"}
REMOTE_SCHEMES = {"ssh", "sftp", "ftp", "ftps", "rsync", "bunker"}

# Hostname labels: letters/digits/hyphen, no leading/trailing hyphen. Also allow
# IPv4 and bracketed IPv6.
_HOST_RE = re.compile(
    r"^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*$"
)
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
        raise TargetError(
            "remote target needs a path below the host, e.g. /srv/code-factory"
        )
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
            return Target(
                raw=raw, kind="local", scheme=scheme, path=_check_local_path(rest)
            )
        if scheme not in REMOTE_SCHEMES:
            raise TargetError(
                f"unsupported scheme {scheme!r}; expected local/file/ssh/sftp/ftp/rsync/bunker"
            )
        if scheme == "bunker":
            agent, _, path = rest.partition("/")
            if not agent:
                raise TargetError(
                    "bunker target needs an agent name: bunker://<agent>/<path>"
                )
            if not _USER_RE.match(agent):
                raise TargetError(f"invalid bunker agent: {agent!r}")
            return Target(
                raw=raw,
                kind="remote",
                scheme=scheme,
                agent=agent,
                path=_check_remote_path("/" + path),
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
        return Target(
            raw=raw, kind="local", scheme="local", path=_check_local_path(text)
        )
    if text.startswith("local:"):
        return Target(
            raw=raw,
            kind="local",
            scheme="local",
            path=_check_local_path(text[len("local:") :]),
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


GIT_BIN = shutil.which("git") or "git"


def _git(root: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [GIT_BIN, "-C", root, *args],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def _local_checkout(path: str) -> dict:
    """Shared existence/git-top-level probe for workdirs and repo_url roots."""
    result = {"path": path, "exists": os.path.isdir(path), "checks": [], "ok": False}
    if not result["exists"]:
        result["checks"].append(
            {"check": "exists", "ok": False, "value": "directory does not exist"}
        )
        return result
    result["checks"].append({"check": "exists", "ok": True, "value": path})
    top = _git(path, "rev-parse", "--show-toplevel")
    toplevel = top.stdout.strip() if top.returncode == 0 else ""
    result["checks"].append(
        {
            "check": "git_toplevel",
            "ok": bool(toplevel),
            "value": toplevel or top.stderr.strip()[:200],
        }
    )
    return result


def verify_local(path: str, home: Optional[str] = None) -> dict:
    """Prove a local target is a usable project checkout, not a parent repo."""
    home = home or os.path.expanduser("~")
    result = _local_checkout(path)

    def add(name: str, ok: bool, value: str) -> None:
        result["checks"].append({"check": name, "ok": ok, "value": value})

    if not result["checks"][-1]["ok"]:
        return result
    toplevel = result["checks"][-1]["value"]
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
    add(
        "has_remote",
        bool(urls),
        json.dumps(urls, sort_keys=True) if urls else "no remote",
    )

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


def verify_bunker(
    target: Target, server: Optional[str] = None, timeout: int = 60
) -> dict:
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
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
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
                rows.append(
                    {"line": lineno, "ok": False, "error": f"invalid JSON: {exc}"}
                )
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


# Satellite-family suffixes, from docs/SCHEDULER-ADMISSION.md's family table (the
# scheduler's `satelliteLaneSuffixes`). For a non-sync lane the primary is the lane
# name with the recognized suffix removed; for -sync the leaf is the full lane
# name, so sync lanes are never grouped with siblings.
FAMILY_SUFFIXES = (
    "-qa",
    "-pm",
    "-sync",
    "-dogfood",
    "-releng",
    "-docs",
    "-readme",
    "-perf",
    "-review",
)


def family_key(name: str) -> str:
    """A row's family grouping key: its primary's name (full name for -sync)."""
    for suffix in FAMILY_SUFFIXES:
        if name.endswith(suffix):
            if suffix == "-sync":
                return name
            return name[: -len(suffix)]
    return name


def normalized_repo_url(raw: str) -> Optional[str]:
    """Comparable form of a repo_url; None when it does not parse at all.

    Local targets compare by their realpath (so `~`, `local:`, `file:`, symlinks
    and trailing slashes that name the same checkout agree); remote targets
    compare by the parser's display form.
    """
    spelling = raw.strip()
    if spelling.startswith("file:") and not spelling.startswith("file://"):
        spelling = "file://" + spelling[len("file:") :]
    try:
        t = parse(spelling)
    except TargetError:
        return None
    if t.is_local:
        value = os.path.realpath(os.path.expanduser(t.path))
    else:
        value = t.display()
    return value.rstrip("/")


def check_repo_url(raw: str, allow_remote: bool) -> str:
    """Reuse target parsing and checkout probes; require a root with a HEAD."""
    # Accept file:<path> here without changing the older parse/verify contract.
    spelling = raw.strip()
    if spelling.startswith("file:") and not spelling.startswith("file://"):
        spelling = "file://" + spelling[len("file:") :]
    target = parse(spelling)
    if not target.is_local:
        out = verify(target, allow_remote=allow_remote)
        return out["verified"] + " — " + out["note"]
    root = os.path.realpath(target.path)
    out = _local_checkout(root)
    if not out["exists"]:
        raise RuntimeError("path does not exist or is not a directory")
    top = out["checks"][-1]
    if not top["ok"]:
        raise RuntimeError(f"not a git root (git: {top['value']})")
    if os.path.realpath(top["value"]) != root:
        raise RuntimeError(f"not a git root (git: top level is {top['value']!r})")
    # CF-097: the same stand-in defect the workdir arm rejects. A path whose git top
    # level IS $HOME is a home meta-repo, not a project checkout, so `repo-url` and
    # `verify` must agree about it. The home is resolved exactly as verify_local()
    # resolves its default (`~`, i.e. $HOME), so both arms name the same directory.
    home_real = os.path.realpath(os.path.expanduser("~"))
    if root == home_real:
        raise RuntimeError(
            f"not_home_repo: git top level is the home directory {home_real!r}"
        )
    head = _git(root, "rev-parse", "--verify", "HEAD")
    if head.returncode:
        raise RuntimeError(f"cannot read HEAD (git: {head.stderr.strip()})")
    return f"root {root!r} HEAD {head.stdout.strip()}"


def repo_urls(
    target: Optional[str], row_file: Optional[str], allow_remote: bool
) -> int:
    """Check a target or JSON project rows, retaining each rejection's exit code."""
    try:
        if row_file is None:
            rows = [{"repo_url": target}]
        else:
            if row_file == "-":
                rows = json.load(sys.stdin)
            else:
                with open(row_file, encoding="utf-8") as fh:
                    rows = json.load(fh)
            if isinstance(rows, dict):
                rows = [rows]
            if not isinstance(rows, list) or not rows:
                raise TargetError("--row requires a project object or nonempty array")
    except (OSError, ValueError) as exc:
        print(f"FAIL repo_url — {exc}")
        print("repo_url: 1 rejected, 0 accepted")
        return 2

    rejected = 0
    codes = set()
    names: list[Optional[str]] = []
    raws: list[object] = []
    ok_row: list[bool] = []
    for row in rows:
        raw = row.get("repo_url") if isinstance(row, dict) else None
        name = (row.get("name") or row.get("id")) if isinstance(row, dict) else None
        label = f" [{name}]" if name else ""
        names.append(name if isinstance(name, str) else None)
        raws.append(raw)
        ok_row.append(True)
        try:
            if not isinstance(raw, str):
                raise TargetError("project row requires a string repo_url")
            message = check_repo_url(raw, allow_remote)
            print(f"PASS repo_url {raw!r} — {message}{label}")
        except (
            TargetError,
            PermissionError,
            RuntimeError,
            OSError,
            subprocess.TimeoutExpired,
        ) as exc:
            code = (
                2
                if isinstance(exc, TargetError)
                else 3
                if isinstance(exc, PermissionError)
                else 4
            )
            codes.add(code)
            ok_row[-1] = False
            print(f"FAIL repo_url {raw!r} — {exc}{label}")

    # Intra-family agreement (CF-091): satellites of one family must carry the
    # primary's repo_url. Two different-but-valid roots both PASS per row, so the
    # value comparison documented in docs/SCHEDULER-ADMISSION.md step 1 is
    # enforced here. Only --row input carries names; single-target calls are
    # untouched, and a row whose repo_url does not parse at all was already
    # rejected above and has nothing comparable.
    if row_file is not None:
        families: dict[str, list[tuple[int, str, str, str]]] = {}
        for idx, (name, raw, ok) in enumerate(zip(names, raws, ok_row)):
            if not ok or not name or not isinstance(raw, str):
                continue
            normalized = normalized_repo_url(raw)
            if normalized is not None:
                families.setdefault(family_key(name), []).append(
                    (idx, name, raw, normalized)
                )
        for primary, members in families.items():
            if len(members) < 2:
                continue
            reference_row = next((m for m in members if m[1] == primary), None)
            reference = (
                reference_row[3]
                if reference_row is not None
                else min(members, key=lambda m: m[1])[3]
            )
            for idx, name, raw, normalized in members:
                if normalized == reference:
                    continue
                codes.add(4)
                ok_row[idx] = False
                print(
                    f"FAIL repo_url {raw!r} — repo_url diverges from primary "
                    f"{primary!r}: {normalized!r} != {reference!r} [{name}]"
                )
    rejected = ok_row.count(False)
    print(f"repo_url: {rejected} rejected, {len(rows) - rejected} accepted")
    # Invalid input takes precedence, then denied remote verification, then local failure.
    return next((code for code in (2, 3, 4) if code in codes), 0)


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

    r = sub.add_parser("repo-url", help="check project repo_url git roots (read-only)")
    source = r.add_mutually_exclusive_group(required=True)
    source.add_argument("target", nargs="?")
    source.add_argument(
        "--row", metavar="FILE", help="JSON object/array; - reads stdin"
    )
    r.add_argument("--allow-remote", action="store_true")

    p2 = sub.add_parser(
        "plan", help="emit bunker:// targets for every lane in a JSONL (writes nothing)"
    )
    p2.add_argument("file")
    p2.add_argument(
        "--agent", required=True, help="bunker agent id that hosts the lane"
    )
    p2.add_argument(
        "--server",
        default=None,
        help="bunker server name (needed to resolve the agent home)",
    )
    p2.add_argument(
        "--suffix",
        default="/repo",
        help="path inside the agent home (default /repo, per specs/NODE.md)",
    )
    p2.add_argument(
        "--path", default=None, help="explicit in-agent path (skips home resolution)"
    )
    p2.add_argument(
        "--prefix", default=None, help="lane-name prefix to keep (e.g. code-factory)"
    )

    a = ap.parse_args(argv)
    try:
        if a.cmd == "repo-url":
            return repo_urls(a.target, a.row, a.allow_remote)
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
                Target(
                    raw=f"bunker://{a.agent}/",
                    kind="remote",
                    scheme="bunker",
                    path="/",
                    agent=a.agent,
                ),
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
                plan.append(
                    {"name": name, "workdir": target, "parsed": asdict(parse(target))}
                )
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
