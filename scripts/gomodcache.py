#!/usr/bin/env python3
"""gomodcache.py — one sealed, shared Go module cache per host (CF-003).

The measurement this exists for: every node re-downloaded a **656 MB** module cache on a
host at 92–98 % disk, because Go's default GOMODCACHE lives inside each node's `$HOME` and
nothing drained it between nodes. The same bytes are identical for every node of a repo.

The fix is to seed one directory once, seal it read-only, and point every node at it:

    gomodcache.py init   --dir /srv/cf/gomod            # create it
    gomodcache.py seed   --dir /srv/cf/gomod --module /path/to/repo   # go mod download …
    gomodcache.py seal   --dir /srv/cf/gomod            # chmod a-w + record bytes/entries
    gomodcache.py check  --dir /srv/cf/gomod            # prove it is sealed and matches
    gomodcache.py wire   --dir /srv/cf/gomod            # go env -w GOMODCACHE=<dir>

Read-only is the contract, not a preference: a sealed cache that a node *can* write to is a
cache that will drift per node and grow to the 656 MB again. `seal` removes every write bit
(owner included) and `check` FAILS when any write bit is back. `unseal` exists for the
prewarm host only. A module absent from a sealed cache fails the build with a named
"read-only file system" error instead of a silent re-download — that is the intended
behaviour and is what the fixture in tests/test_node_provisioning.py asserts.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path

MANIFEST = ".cf-gomodcache.json"
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


def tree_stats(root: Path) -> tuple[int, int]:
    """(bytes, entries) under root, never following symlinks, manifest excluded."""
    total = 0
    entries = 0
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d != MANIFEST]
        for name in files:
            if name == MANIFEST:
                continue
            path = Path(base) / name
            try:
                if path.is_symlink():
                    continue
                total += path.stat().st_size
                entries += 1
            except OSError:
                continue
    return total, entries


def writable_paths(root: Path, limit: int = 5) -> list[str]:
    """Every path under root that any write bit is set on (the sealing contract)."""
    found: list[str] = []
    try:
        if stat.S_IMODE(root.stat().st_mode) & 0o222:
            found.append(str(root))
    except OSError:
        return found
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(base) / name
            try:
                if path.is_symlink():
                    continue
                if stat.S_IMODE(path.stat().st_mode) & 0o222:
                    found.append(str(path))
                    if len(found) >= limit:
                        return found
            except OSError:
                continue
    return found


def load_manifest(root: Path) -> dict | None:
    try:
        return json.loads((root / MANIFEST).read_text())
    except (OSError, ValueError):
        return None


def write_manifest(root: Path, data: dict) -> None:
    path = root / MANIFEST
    path.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")
    os.chmod(path, 0o444)


def cmd_init(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    if root.exists() and not root.is_dir():
        bad("modcache", f"{root} exists and is not a directory")
        return 1
    root.mkdir(parents=True, exist_ok=True)
    if args.unseal:
        for base, dirs, files in os.walk(root):
            for name in dirs + files:
                try:
                    os.chmod(
                        Path(base) / name,
                        0o755 if (Path(base) / name).is_dir() else 0o644,
                    )
                except OSError:
                    pass
        os.chmod(root, 0o755)
    ok("modcache", f"{root} present ({tree_stats(root)[0] / 1048576:.1f} MiB)")
    return 0


def cmd_seed(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    module = Path(os.path.expanduser(args.module)).resolve()
    go = shutil.which("go") or shutil.which(
        os.path.expanduser("~/go-toolchain/current/bin/go")
    )
    if not go:
        bad("go", "no go binary on PATH — cannot seed the module cache")
        return 1
    if not (module / "go.mod").is_file():
        bad("module", f"{module} has no go.mod — seeding needs a module root")
        return 1
    env = dict(os.environ)
    env.update(
        {"GOMODCACHE": str(root), "GOFLAGS": "-modcacherw", "GOTOOLCHAIN": "local"}
    )
    before = tree_stats(root)[0]
    proc = subprocess.run(
        [go, "mod", "download", "all"],
        cwd=str(module),
        env=env,
        capture_output=True,
        text=True,
    )
    after = tree_stats(root)[0]
    if proc.returncode != 0:
        bad(
            "seed",
            f"go mod download all exited {proc.returncode}: "
            f"{(proc.stderr or proc.stdout).strip().splitlines()[-1][:200] if (proc.stderr or proc.stdout).strip() else 'no output'}",
        )
        return 1
    ok(
        "seed",
        f"{module} -> {root} (+{(after - before) / 1048576:.1f} MiB, total {after / 1048576:.1f} MiB)",
    )
    return 0


def cmd_seal(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    if not root.is_dir():
        bad("modcache", f"{root} is not a directory — run init first")
        return 1
    for base, dirs, files in os.walk(root, topdown=True, followlinks=False):
        for name in files:
            path = Path(base) / name
            if path.is_symlink():
                continue
            try:
                os.chmod(path, 0o444)
            except OSError as exc:
                bad("seal", f"cannot chmod {path}: {exc}")
        for name in dirs:
            path = Path(base) / name
            if path.is_symlink():
                continue
            try:
                os.chmod(path, 0o555)
            except OSError as exc:
                bad("seal", f"cannot chmod {path}: {exc}")
    total, entries = tree_stats(root)
    # The manifest is written while the root is still writable, then every write bit —
    # the root's included — comes off, and the check runs against the final state.
    write_manifest(
        root,
        {
            "bytes": total,
            "entries": entries,
            "sealed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "note": "sealed read-only; unseal only on the prewarm host",
        },
    )
    os.chmod(root, 0o555)
    writable = writable_paths(root, limit=3)
    if writable:
        bad("seal", f"{len(writable)} path(s) still writable: {', '.join(writable)}")
        return 1
    ok("seal", f"{root} read-only — {total / 1048576:.1f} MiB in {entries} files")
    return 0


def cmd_unseal(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    if not root.is_dir():
        bad("modcache", f"{root} is not a directory")
        return 1
    for base, dirs, files in os.walk(root, topdown=False, followlinks=False):
        for name in files:
            path = Path(base) / name
            if not path.is_symlink():
                try:
                    os.chmod(path, 0o644)
                except OSError:
                    pass
        for name in dirs:
            path = Path(base) / name
            if not path.is_symlink():
                try:
                    os.chmod(path, 0o755)
                except OSError:
                    pass
    os.chmod(root, 0o755)
    if (root / MANIFEST).exists():
        os.chmod(root / MANIFEST, 0o644)
    ok("unseal", f"{root} writable (prewarm only — re-seal before nodes use it)")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    if not root.is_dir():
        bad("modcache", f"{root} does not exist — nodes keep a private 656 MB cache")
        return 1
    total, entries = tree_stats(root)
    ok("modcache", f"{root} present ({total / 1048576:.1f} MiB in {entries} files)")
    writable = writable_paths(root, limit=3)
    if writable:
        bad(
            "modcache_seal",
            f"{len(writable)} writable path(s) — a node can re-download: "
            f"{', '.join(writable)}",
        )
    else:
        ok("modcache_seal", f"{root} read-only (no write bits, owner included)")
    manifest = load_manifest(root)
    if manifest is None:
        bad(
            "modcache_manifest",
            f"{root / MANIFEST} absent — the cache size is unmeasured, "
            f"so no drift can be detected (run seal)",
        )
    else:
        delta = total - int(manifest.get("bytes", 0))
        if delta == 0:
            ok(
                "modcache_manifest",
                f"matches seal record ({int(manifest['bytes']) / 1048576:.1f} MiB, "
                f"sealed {manifest.get('sealed_at', '?')})",
            )
        else:
            bad(
                "modcache_manifest",
                f"{delta:+d} bytes since seal ({manifest.get('sealed_at', '?')}) "
                f"— the cache changed after it was sealed",
            )
    if args.json:
        print(
            json.dumps(
                {
                    "dir": str(root),
                    "bytes": total,
                    "entries": entries,
                    "writable": writable,
                    "manifest": manifest,
                },
                sort_keys=True,
            )
        )
    return 0 if failures == 0 else 1


def cmd_measure(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    if not root.is_dir():
        bad("modcache", f"{root} does not exist")
        return 1
    total, entries = tree_stats(root)
    payload = {
        "dir": str(root),
        "bytes": total,
        "mib": round(total / 1048576, 1),
        "entries": entries,
    }
    if args.json:
        print(json.dumps(payload, sort_keys=True))
    else:
        print(f"{payload['mib']} MiB in {entries} files at {root}")
    return 0


def cmd_env(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    print(f"export GOMODCACHE={root}")
    print(f"go env -w GOMODCACHE={root}")
    return 0


def cmd_wire(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.dir))
    go = args.go or shutil.which("go")
    if not go:
        bad("go", "no go binary on PATH — GOMODCACHE was not written")
        return 1
    if not root.is_dir():
        bad("modcache", f"{root} does not exist — wire it after init/seed/seal")
        return 1
    proc = subprocess.run(
        [go, "env", "-w", f"GOMODCACHE={root}"], capture_output=True, text=True
    )
    if proc.returncode != 0:
        bad(
            "wire",
            f"go env -w exited {proc.returncode}: {(proc.stderr or proc.stdout).strip()[:200]}",
        )
        return 1
    proc = subprocess.run([go, "env", "GOMODCACHE"], capture_output=True, text=True)
    observed = proc.stdout.strip()
    if observed == str(root):
        ok("wire", f"go env GOMODCACHE -> {observed}")
    else:
        bad("wire", f"go env GOMODCACHE -> {observed!r} (wanted {root})")
    return 0 if failures == 0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="sealed shared Go module cache")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("init", help="create the shared cache directory")
    p.add_argument("--dir", required=True)
    p.add_argument(
        "--unseal", action="store_true", help="make an existing cache writable first"
    )
    p.set_defaults(func=cmd_init)

    p = sub.add_parser("seed", help="download a module's dependencies into the cache")
    p.add_argument("--dir", required=True)
    p.add_argument("--module", required=True)
    p.set_defaults(func=cmd_seed)

    p = sub.add_parser("seal", help="remove every write bit and record bytes/entries")
    p.add_argument("--dir", required=True)
    p.set_defaults(func=cmd_seal)

    p = sub.add_parser(
        "unseal", help="make the cache writable again (prewarm host only)"
    )
    p.add_argument("--dir", required=True)
    p.set_defaults(func=cmd_unseal)

    p = sub.add_parser("check", help="prove the cache is sealed and matches its record")
    p.add_argument("--dir", required=True)
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("measure", help="print the cache size")
    p.add_argument("--dir", required=True)
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_measure)

    p = sub.add_parser("env", help="print the export / go env -w line for a node")
    p.add_argument("--dir", required=True)
    p.set_defaults(func=cmd_env)

    p = sub.add_parser("wire", help="write GOMODCACHE into the go env file")
    p.add_argument("--dir", required=True)
    p.add_argument("--go")
    p.set_defaults(func=cmd_wire)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
