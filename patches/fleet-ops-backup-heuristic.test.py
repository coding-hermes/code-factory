#!/usr/bin/env python3
"""Regression arms for the fleet ops census backup heuristic (CF-370).

Target: the fleet ops census script (default `~/.hermes/scripts/fleet_ops_check.py`), passed as
argv[1]. This tests the PATCHED build: the patch `fleet-ops-backup-heuristic.patch` beside this
file applies to the pristine script whose sha256 is recorded in the patch preamble.

CF-370: `check=backup` fired on 26 of 88 families. 15 of them only because the foreman board's own
DDL (`.coding-hermes/board/schema.sql`) sits under the repo root, and 10 more because the backup
arm matched whole path COMPONENTS only, so `docs/backup-set.md` and `scripts/backup-db.sh` were
invisible. Two negative controls keep the check alive.

Run: python3 patches/fleet-ops-backup-heuristic.test.py [target-script]
Exit 0 only when every arm passes.
"""

import importlib.util
import os
import shutil
import sys
import tempfile

DEFAULT_TARGET = os.path.expanduser("~/.hermes/scripts/fleet_ops_check.py")
TARGET = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_TARGET)

# Families that fired check=backup ONLY because of `.coding-hermes/board/schema.sql`, plus the one
# that also carried `.gitreins/state.db`. Recorded from the live census JSON (not re-swept here, so
# the test stays fast); each names the path that triggered the finding.
HARNESS_TRIGGERED = [
    ("9router", ".coding-hermes/board/schema.sql"),
    ("bunker", ".coding-hermes/board/schema.sql"),
    ("chimera-v2", ".coding-hermes/board/schema.sql"),
    ("coding-hermes-scheduler", ".coding-hermes/board/schema.sql"),
    ("doc-writer", ".coding-hermes/board/schema.sql"),
    ("duckbrain", ".coding-hermes/board/schema.sql"),
    ("eduos.dexdat.com.co", ".coding-hermes/board/schema.sql"),
    ("gitreins", ".coding-hermes/board/schema.sql"),
    ("hermes-dagger", ".coding-hermes/board/schema.sql"),
    ("hivemind-work", ".coding-hermes/board/schema.sql"),
    ("mafia-ai-benchmark", ".coding-hermes/board/schema.sql"),
    ("musterflow", ".coding-hermes/board/schema.sql"),
    ("terminal-jail", ".coding-hermes/board/schema.sql"),
    ("trouble", ".coding-hermes/board/schema.sql"),
    ("wojons-mythos", ".coding-hermes/board/schema.sql"),
    ("ai-plays-poke", ".gitreins/state.db"),
]

SERVICE_EV = {
    "server_entrypoint": True,
    "container": "Dockerfile",
    "supervision": "deploy",
    "orchestration": "deploy",
}

failures = []


def check(name, cond, detail=""):
    if cond:
        print("  PASS %s" % name)
    else:
        print("  FAIL %s %s" % (name, detail))
        failures.append(name)


def load_module(path):
    spec = importlib.util.spec_from_file_location("census_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def backup_gaps(mod, root):
    return [
        g
        for g in mod.ops_gaps("service", root, dict(SERVICE_EV))
        if g["check"] == "backup"
    ]


def fixture(tmp, name, files):
    root = os.path.join(tmp, name)
    for rel in files:
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True) if os.path.dirname(p) else None
        with open(p, "w") as fh:
            fh.write("-- fixture\n" if rel.endswith(".sql") else "fixture\n")
    os.makedirs(root, exist_ok=True)
    return root


def main():
    if not os.path.isfile(TARGET):
        print("FAIL target script not found: %s" % TARGET)
        return 2
    mod = load_module(TARGET)
    print("target: %s" % TARGET)

    # --- arm 1: harness bookkeeping is not a project datastore -------------------------------
    print("arm 1: harness bookkeeping excluded from owns_store")
    for fam, trig in HARNESS_TRIGGERED:
        check(
            "harness path classified: %s -> %s" % (fam, trig),
            bool(getattr(mod, "is_harness_path", lambda _p: False)(trig)),
            "(is_harness_path missing or returned False)",
        )
    tmp = tempfile.mkdtemp(prefix="cf370-arm1-")
    try:
        r = fixture(tmp, "board-only", [".coding-hermes/board/schema.sql"])
        check(
            "board schema alone -> no backup gap",
            backup_gaps(mod, r) == [],
            repr(backup_gaps(mod, r)),
        )
        r = fixture(tmp, "ledger-only", [".gitreins/state.db"])
        check(
            ".gitreins/state.db alone -> no backup gap",
            backup_gaps(mod, r) == [],
            repr(backup_gaps(mod, r)),
        )
        r = fixture(
            tmp,
            "board-and-ledger",
            [".coding-hermes/board/schema.sql", ".gitreins/state.db"],
        )
        check(
            "board + ledger -> no backup gap",
            backup_gaps(mod, r) == [],
            repr(backup_gaps(mod, r)),
        )
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # --- arm 2: a backup/restore artifact whose BASENAME carries the word -------------------
    print("arm 2: backup artifact accepted by basename substring")
    for rel in (
        "docs/backup-set.md",
        "docs/runbooks/backup-restore.md",
        "scripts/backup-db.sh",
        "scripts/restore-db.sh",
        "docs/SNAPSHOT-policy.md",
    ):
        tmp = tempfile.mkdtemp(prefix="cf370-arm2-")
        try:
            r = fixture(tmp, "store-plus-artifact", ["migrations/001.sql", rel])
            check(
                "migrations + %s -> no backup gap" % rel,
                backup_gaps(mod, r) == [],
                repr(backup_gaps(mod, r)),
            )
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    tmp = tempfile.mkdtemp(prefix="cf370-arm2b-")
    try:
        r = fixture(tmp, "component-dir", ["migrations/001.sql", "backup/README.txt"])
        check(
            "whole-component backup/ dir still counts",
            backup_gaps(mod, r) == [],
            repr(backup_gaps(mod, r)),
        )
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # --- arm 3: negative control — a genuine store with no backup path still reports --------
    print("arm 3: negative control, genuine store with no backup path")
    tmp = tempfile.mkdtemp(prefix="cf370-arm3-")
    try:
        r = fixture(tmp, "genuine-store", ["migrations/001.sql"])
        gaps = backup_gaps(mod, r)
        check("migrations only -> backup gap reported", len(gaps) == 1, repr(gaps))
        check(
            "migrations only -> severity P1",
            bool(gaps) and gaps[0]["severity"] == "P1",
            repr(gaps),
        )
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # --- arm 4: negative control the exclusion could break ---------------------------------
    print("arm 4: negative control, real store beside the harness bookkeeping")
    for store in ("data.db", "store.db", "state.db"):
        tmp = tempfile.mkdtemp(prefix="cf370-arm4-")
        try:
            r = fixture(
                tmp, "board-beside-store", [".coding-hermes/board/schema.sql", store]
            )
            gaps = backup_gaps(mod, r)
            check(
                ".coding-hermes board + %s -> backup gap still reported" % store,
                len(gaps) == 1,
                repr(gaps),
            )
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failures:
        print("FAILED: %d arm(s): %s" % (len(failures), ", ".join(failures)))
        return 1
    print("OK: all arms passed against %s" % TARGET)
    return 0


if __name__ == "__main__":
    sys.exit(main())
