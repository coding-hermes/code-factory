#!/usr/bin/env python3
"""P5G-20 probe — drive the shipped provisioning generation/retry surfaces offline.

Imports the shipped modules from scripts/ and drives, with no network, no bunker
call and no writes outside a temporary directory:

  1. the only retry rule implemented in this tree — scripts/configure_family.py's
     bounded busy retry: the attempt cap, the monotonically increasing backoff
     schedule, the busy/not-busy classification, and the per-lane outcome
     vocabulary (configured / already / failed);
  2. the durable identity store — scripts/node_identity.py's idempotent merge
     into a mode-600 node.json, its refusal to touch an unreadable store, and
     its read-modify-write-only-what-changed contract;
  3. the seed digest-record state machine — scripts/node_seed.py's build/check/
     apply: digest-recorded build, drift refused by check, re-apply preserving a
     node-local edit without --force and replacing it with --force.

Prints one stable token per measured property and `P5G20 PROBE: PASS` only when
every property held. Run from the repository root:

    python3 docs/audits/p5g20-probe-provisioning-lifecycle.py
"""

import contextlib
import hashlib
import importlib.util
import io
import json
import os
import shutil
import sqlite3
import stat
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(name):
    """Import scripts/<name>.py under its own module name."""
    path = os.path.join(ROOT, "scripts", name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def mode_of(path):
    return stat.S_IMODE(os.stat(path).st_mode)


def sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


failures = []


def check(label, condition, detail=""):
    if condition:
        print(label)
    else:
        failures.append(label)
        print(f"{label}  [FAILED] {detail}")


def main():
    tmp = tempfile.mkdtemp(prefix="p5g20-probe-")
    try:
        # ---- 1. the shipped retry rule (scripts/configure_family.py) ----
        cf = load("configure_family")
        schedule = [cf.busy_backoff(a) for a in range(1, cf.BUSY_ATTEMPTS + 1)]
        check(
            "retry_attempts %d" % cf.BUSY_ATTEMPTS,
            cf.BUSY_ATTEMPTS == 5,
            "expected the shipped cap 5",
        )
        check(
            "retry_backoff %s" % schedule,
            schedule == [0.25, 0.5, 1.0, 2.0, 4.0],
            "expected the shipped 0.25 s x 2^n schedule",
        )
        check(
            "retry_classify busy_locked=%s busy_busy=%s not_busy=%s"
            % (
                cf.is_busy(RuntimeError("database is locked")),
                cf.is_busy(RuntimeError("DATABASE IS BUSY")),
                cf.is_busy(RuntimeError("no such table: projects")),
            ),
            cf.is_busy(RuntimeError("database is locked"))
            and cf.is_busy(RuntimeError("DATABASE IS BUSY"))
            and not cf.is_busy(RuntimeError("no such table: projects")),
            "classification must accept both busy spellings and refuse others",
        )

        # A real one-lane scheduler DB: the same idempotency vocabulary the
        # docstring records — configured, already, failed.
        db = os.path.join(tmp, "sched.db")
        con = sqlite3.connect(db)
        con.execute(
            "CREATE TABLE projects (name TEXT, parent TEXT, admission_mode TEXT,"
            " prompt TEXT, prompt_mode TEXT, cooldown_floor_s INTEGER,"
            " cooldown_ceiling_s INTEGER)"
        )
        con.execute(
            "INSERT INTO projects VALUES ('cf-lane', 'cf', 'tasks', '', 'p', 0, 0)"
        )
        desired = {
            "parent": "cf",
            "admission_mode": "tasks",
            "prompt": "P",
            "prompt_mode": "p",
            "cooldown_floor_s": 5,
            "cooldown_ceiling_s": 60,
        }
        sleeps = []
        first = cf.configure_lane(con, "cf-lane", desired, sleep=sleeps.append)
        second = cf.configure_lane(con, "cf-lane", desired)
        absent = cf.configure_lane(con, "cf-absent", desired)
        check(
            "retry_outcomes %s/%s/%s reason=%r sleeps=%d"
            % (first.kind, second.kind, absent.kind, absent.reason, len(sleeps)),
            first.kind == "configured"
            and second.kind == "already"
            and absent.kind == "failed"
            and absent.reason == "no project row to configure"
            and sleeps == [],
            "expected configured, already, failed, and no backoff sleep on a clean write",
        )
        con.close()

        # ---- 2. the durable identity store (scripts/node_identity.py) ----
        ni = load("node_identity")
        node_json = os.path.join(tmp, "node.json")
        with contextlib.redirect_stdout(io.StringIO()) as cap:
            rc1 = ni.main(
                [node_json, "namespace=code-factory", "bus.base=http://h:8767"]
            )
        first_text = cap.getvalue()
        with contextlib.redirect_stdout(io.StringIO()) as cap2:
            rc2 = ni.main(
                [node_json, "namespace=code-factory", "bus.base=http://h:8767"]
            )
        check(
            "identity_merge rc=%d/%d mode=%03o merged=%s idempotent=%s"
            % (
                rc1,
                rc2,
                mode_of(node_json),
                "merged" in first_text,
                "unchanged" in cap2.getvalue(),
            ),
            rc1 == 0
            and rc2 == 0
            and mode_of(node_json) == 0o600
            and "merged" in first_text
            and "unchanged" in cap2.getvalue(),
            "expected merge then idempotent no-op at mode 600",
        )
        with open(node_json) as fh:
            doc = json.load(fh)
        check(
            "identity_keeps_schema %s" % sorted(doc.keys()),
            doc.get("namespace") == "code-factory"
            and doc.get("bus", {}).get("base") == "http://h:8767",
            "dotted keys must land nested without deleting siblings",
        )

        broken = os.path.join(tmp, "broken.json")
        with open(broken, "w") as fh:
            fh.write("{ not json")
        with (
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()) as cap_err,
        ):
            rc3 = ni.main([broken, "namespace=x"])
        check(
            "identity_refused_unreadable rc=%d untouched=%s named=%s"
            % (
                rc3,
                open(broken).read() == "{ not json",
                "not a readable JSON object" in cap_err.getvalue(),
            ),
            rc3 == 1
            and open(broken).read() == "{ not json"
            and "not a readable JSON object" in cap_err.getvalue(),
            "an unreadable store is refused, named and left byte-identical",
        )

        # ---- 3. the seed digest-record state machine (scripts/node_seed.py) ----
        ns = load("node_seed")
        repo = os.path.join(tmp, "repo")
        os.makedirs(os.path.join(repo, "skills"))
        with open(os.path.join(repo, "skills", "x.txt"), "w") as fh:
            fh.write("seed-v1\n")
        manifest = os.path.join(repo, "seed-manifest.txt")
        with open(manifest, "w") as fh:
            fh.write("skills/x.txt\n")
        tar_path = os.path.join(tmp, "seed.tar.gz")

        build = __import__("argparse").Namespace(
            manifest=manifest,
            repo_root=repo,
            out=tar_path,
            budget=1_000_000,
            exclude_backups=True,
        )
        with contextlib.redirect_stdout(io.StringIO()):
            rc_build = ns.build(build)
        record_path = tar_path + ".json"
        with open(record_path) as fh:
            record = json.load(fh)
        check(
            "seed_build rc=%d files=%d digest=%s"
            % (rc_build, len(record["files"]), record["files"][0]["sha256"][:12]),
            rc_build == 0
            and len(record["files"]) == 1
            and record["files"][0]["sha256"]
            == sha(os.path.join(repo, "skills", "x.txt")),
            "build must record one sha256 per declared file",
        )

        home = os.path.join(tmp, "home")
        ap = __import__("argparse").Namespace(
            tar=tar_path, record=record_path, home=home, force=False
        )
        with contextlib.redirect_stdout(io.StringIO()):
            rc_apply = ns.apply_seed(ap)
        dest = os.path.join(home, ".hermes", "skills", "x.txt")
        check(
            "seed_apply rc=%d mode_ok=%s applied_record=%s"
            % (
                rc_apply,
                os.path.isfile(dest),
                os.path.isfile(os.path.join(home, ".hermes", "seed-applied.json")),
            ),
            rc_apply == 0
            and os.path.isfile(dest)
            and os.path.isfile(os.path.join(home, ".hermes", "seed-applied.json")),
            "apply installs the digested files and writes the applied record",
        )

        # A node-local edit is a CONFLICT with the seed record: check refuses it,
        # and a plain re-apply preserves it instead of silently overwriting.
        with open(dest, "w") as fh:
            fh.write("node-local edit\n")
        ck = __import__("argparse").Namespace(record=record_path, home=home)
        with contextlib.redirect_stdout(io.StringIO()) as cap_ck:
            rc_drift = ns.check_seed(ck)
        check(
            "seed_drift rc=%d named=%s"
            % (rc_drift, "skills/x.txt drifted" in cap_ck.getvalue()),
            rc_drift == 1 and "skills/x.txt drifted" in cap_ck.getvalue(),
            "check must refuse a digested file that differs, naming it",
        )
        with contextlib.redirect_stdout(io.StringIO()) as cap_keep:
            rc_keep = ns.apply_seed(ap)
        check(
            "seed_preserve rc=%d content=%s named=%s"
            % (
                rc_keep,
                open(dest).read().strip(),
                "preserved skills/x.txt (changed locally" in cap_keep.getvalue(),
            ),
            rc_keep == 0
            and open(dest).read() == "node-local edit\n"
            and "preserved skills/x.txt (changed locally" in cap_keep.getvalue(),
            "a plain re-apply preserves the node-local edit and names it",
        )
        force = __import__("argparse").Namespace(
            tar=tar_path, record=record_path, home=home, force=True
        )
        with contextlib.redirect_stdout(io.StringIO()):
            rc_force = ns.apply_seed(force)
        check(
            "seed_force rc=%d content=%s" % (rc_force, open(dest).read().strip()),
            rc_force == 0 and open(dest).read() == "seed-v1\n",
            "--force is the only path that replaces the node-local edit",
        )

        if failures:
            print("P5G20 PROBE: FAIL (%s)" % ", ".join(failures))
            return 1
        print("P5G20 PROBE: PASS")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
