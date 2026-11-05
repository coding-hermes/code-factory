#!/usr/bin/env python3
"""node_seed.py — seed a node's prompts and skills, digest-recorded (CF-220).

A node that runs a foreman needs the foreman's procedure and the skills that
procedure names. Nothing shipped them, so the node had a harness with nothing
to run: "this run's tools are on the host" was the node's own report.

This script is a three-part contract:

  --build   on the control host: read the declared manifest, refuse anything
            outside it or over the size budget, write a tarball plus a JSON
            record of every path and its sha256.
  --apply   on the node: extract the tarball into $HOME/.hermes, verify each
            file against the record BEFORE installing it, and write what was
            applied and when. A digest mismatch refuses the whole seed.
  --check   on either side: compare what is on disk with what was recorded and
            exit 1 on any drift, naming the path.

What is deliberately NOT seeded: backup tarballs, and the whole user skill
library. Only the declared list is ever copied — the exclusion is by
construction, not by a filter that could miss a pattern.

Exit codes: 0 done, 1 refused/drifted, 2 usage.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tarfile
import tempfile
import time

DEFAULT_MANIFEST = "config/node-seed.txt"
DEFAULT_BUDGET = 16 * 1024 * 1024  # ~16 MB, the declared ceiling


def say(msg: str) -> None:
    print(msg)


def ok(name: str, detail: str) -> None:
    print("  PASS  %s — %s" % (name, detail))


def bad(name: str, detail: str) -> None:
    print("  FAIL  %s — %s" % (name, detail))


def note(msg: str) -> None:
    print("  ..    %s" % msg)


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def read_manifest(path: str, repo_root: str) -> list[str]:
    """Declared paths, comments and blank lines ignored. Globs are expanded
    against the repo root, never against the filesystem at large."""
    entries: list[str] = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            entries.append(line)

    import glob as globmod

    resolved: list[str] = []
    for entry in entries:
        pattern = os.path.join(repo_root, entry)
        if any(ch in entry for ch in "*?["):
            hits = sorted(globmod.glob(pattern, recursive=True))
            if not hits:
                # An empty glob is legitimate (no .sh in this tree today) and is
                # reported, not refused: refusing would make the manifest fail
                # on a repository that is merely tidy. A missing LITERAL path is
                # still a refusal, because that is where a typo hides.
                note("manifest glob matched nothing: %s" % entry)
                continue
            resolved.extend(hits)
        else:
            if not os.path.exists(pattern):
                raise SystemExit("REFUSED: manifest entry missing: %s" % entry)
            resolved.append(pattern)

    # De-duplicate, keep order.
    seen: set[str] = set()
    out: list[str] = []
    for p in resolved:
        rp = os.path.realpath(p)
        if rp in seen:
            continue
        seen.add(rp)
        out.append(p)
    return out


def build(args: argparse.Namespace) -> int:
    repo_root = os.path.realpath(args.repo_root or os.getcwd())
    files = read_manifest(args.manifest, repo_root)

    records = []
    total = 0
    for path in files:
        if os.path.isdir(path):
            bad("seed_manifest", "%s is a directory — declare files, not trees" % path)
            return 1
        rel = os.path.relpath(os.path.realpath(path), repo_root)
        if args.exclude_backups and (rel.startswith("backups/") or rel.endswith(".tar.gz")):
            bad("seed_manifest", "%s is a backup artefact and may not be seeded" % rel)
            return 1
        digest = sha256_file(path)
        size = os.path.getsize(path)
        total += size
        records.append({"path": rel, "sha256": digest, "bytes": size})

    if total > args.budget:
        bad("seed_budget", "%d bytes exceeds the declared ceiling of %d" % (total, args.budget))
        return 1

    ok("seed_manifest", "%d files declared, %d bytes (ceiling %d)" % (len(records), total, args.budget))

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with tarfile.open(args.out, "w:gz") as tar:
        for rec in records:
            tar.add(os.path.join(repo_root, rec["path"]), arcname=rec["path"])

    record = {
        "built_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "repo_root": repo_root,
        "manifest": os.path.relpath(args.manifest, repo_root),
        "total_bytes": total,
        "files": records,
    }
    rec_path = args.out + ".json"
    with open(rec_path, "w", encoding="utf-8") as fh:
        json.dump(record, fh, indent=2, sort_keys=True)
        fh.write("\n")

    ok("seed_record", "%s (%d files, sha256 per file)" % (rec_path, len(records)))
    for rec in records:
        note("%s  %s" % (rec["sha256"][:12], rec["path"]))
    return 0


def load_record(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def apply_seed(args: argparse.Namespace) -> int:
    record = load_record(args.record)
    home = os.path.expanduser(args.home)
    hermes = os.path.join(home, ".hermes")
    os.makedirs(hermes, exist_ok=True)

    # Extract to a staging directory first: nothing lands in place until every
    # digest in the record has been confirmed.
    staging = tempfile.mkdtemp(prefix="node-seed-", dir=home)
    try:
        with tarfile.open(args.tar, "r:gz") as tar:
            for member in tar.getmembers():
                target = os.path.realpath(os.path.join(staging, member.name))
                if not target.startswith(os.path.realpath(staging) + os.sep):
                    bad("seed_extract", "refusing path traversal in archive: %s" % member.name)
                    return 1
            tar.extractall(staging)

        mismatches = 0
        for rec in record["files"]:
            staged = os.path.join(staging, rec["path"])
            if not os.path.exists(staged):
                bad("seed_digest", "%s missing from the archive" % rec["path"])
                mismatches += 1
                continue
            got = sha256_file(staged)
            if got != rec["sha256"]:
                bad("seed_digest", "%s digest %s != recorded %s" % (rec["path"], got[:12], rec["sha256"][:12]))
                mismatches += 1
        if mismatches:
            bad("seed_apply", "%d file(s) failed the digest check — nothing installed" % mismatches)
            return 1
        ok("seed_digest", "all %d files match the record" % len(record["files"]))

        # prompts/ and skills/ are replaced as directories so a deleted source
        # file does not survive on the node as a ghost.
        for top in ("prompts", "skills"):
            dst = os.path.join(hermes, top)
            src = os.path.join(staging, top)
            if not os.path.isdir(src):
                continue
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
            ok("seed_install", "%s/ installed (%d files)" % (top, sum(len(f) for _, _, f in os.walk(dst))))

        applied = dict(record)
        applied["applied_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        applied["applied_to"] = hermes
        out = os.path.join(hermes, "seed-applied.json")
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(applied, fh, indent=2, sort_keys=True)
            fh.write("\n")
        ok("seed_record", "%s written" % out)
        return 0
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def check_seed(args: argparse.Namespace) -> int:
    record = load_record(args.record)
    home = os.path.expanduser(args.home)
    hermes = os.path.join(home, ".hermes")

    drift = 0
    for rec in record["files"]:
        path = os.path.join(hermes, rec["path"])
        if not os.path.exists(path):
            bad("seed_check", "%s absent on the node" % rec["path"])
            drift += 1
            continue
        got = sha256_file(path)
        if got != rec["sha256"]:
            bad("seed_check", "%s drifted (%s != %s)" % (rec["path"], got[:12], rec["sha256"][:12]))
            drift += 1

    if drift:
        bad("seed_check", "%d of %d seeded files differ from the record" % (drift, len(record["files"])))
        return 1
    ok("seed_check", "%d files present and matching" % len(record["files"]))
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Seed a node's prompts and skills, digest-recorded (CF-220).")
    sub = ap.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("build", help="control host: build the tarball and the digest record")
    b.add_argument("--manifest", default=DEFAULT_MANIFEST)
    b.add_argument("--repo-root", default="")
    b.add_argument("--out", required=True)
    b.add_argument("--budget", type=int, default=DEFAULT_BUDGET)
    b.add_argument("--exclude-backups", action="store_true", default=True)

    a = sub.add_parser("apply", help="node: verify then install")
    a.add_argument("--tar", required=True)
    a.add_argument("--record", required=True)
    a.add_argument("--home", default="~")

    c = sub.add_parser("check", help="compare the node against the record")
    c.add_argument("--record", required=True)
    c.add_argument("--home", default="~")

    args = ap.parse_args(argv)
    if args.cmd == "build":
        return build(args)
    if args.cmd == "apply":
        return apply_seed(args)
    if args.cmd == "check":
        return check_seed(args)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
