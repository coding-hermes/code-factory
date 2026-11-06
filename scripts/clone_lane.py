#!/usr/bin/env python3
"""clone_lane.py — create a lane row by cloning a canonical sibling.

Why this exists: the scheduler's lane-onboarding gate refuses EVERY workdir for families it
recognises but has no workdir root for (docs, readme, perf, review — SCHED-GAP-1733 criterion 2
keeps them "offboarded"). Existing live lanes in those families predate the gate. So the only
way to give a new project the same shape is to clone a live row.

Usage:
  clone_lane.py --from crier-docs --to code-factory-docs --workdir <path> \
                --namespace docs --parent code-factory --prompt prompts/docs.md

`--to` must differ from `--from`. This script REFUSES a `--to` equal to its `--from`, before it
opens the database at all: a lane cannot be its own clone, and treating the source as the
destination rewrites — and disables — a LIVE lane instead of failing. The refusal exits 2 and
names both arguments:

  REFUSED: --to and --from are the same lane (code-factory-docs); refusing to rewrite the source row

`--db` names the scheduler database; it defaults to $SCHEDULER_DB when that is set, else
~/.hermes/coding-hermes/scheduler.db.
"""

import argparse
import os
import sqlite3
import sys
import time


def default_db():
    """The scheduler DB: $SCHEDULER_DB when set, else the host default."""
    return os.environ.get("SCHEDULER_DB") or os.path.expanduser(
        "~/.hermes/coding-hermes/scheduler.db"
    )


def refuse_same_lane(lane):
    """Stop before any DB work: the source row is not a clone destination."""
    print(
        f"REFUSED: --to and --from are the same lane ({lane}); "
        "refusing to rewrite the source row",
        file=sys.stderr,
    )
    print(f"  --from={lane} --to={lane}", file=sys.stderr)
    raise SystemExit(2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True)
    ap.add_argument("--to", dest="dst", required=True)
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--namespace", required=True)
    ap.add_argument("--parent", required=True)
    ap.add_argument("--prompt")
    ap.add_argument(
        "--db",
        default=default_db(),
        help="scheduler database (default: $SCHEDULER_DB, else "
        "~/.hermes/coding-hermes/scheduler.db)",
    )
    a = ap.parse_args()

    # CF-357: refuse BEFORE sqlite3.connect. Same name would fetch the source row, rewrite it
    # as the destination, then UPDATE ... WHERE name=<same name> — disabling a live lane.
    if a.src == a.dst:
        refuse_same_lane(a.dst)

    con = sqlite3.connect(a.db, timeout=60)
    con.execute("PRAGMA busy_timeout=60000")
    con.row_factory = sqlite3.Row

    src = con.execute("SELECT * FROM projects WHERE name=?", (a.src,)).fetchone()
    if src is None:
        raise SystemExit(f"source lane {a.src} not found")
    if con.execute("SELECT 1 FROM projects WHERE name=?", (a.dst,)).fetchone():
        print(f"{a.dst} already exists — configuring it instead of creating")
        row = dict(src)
    else:
        row = dict(src)
    row.update(
        {
            "name": a.dst,
            "workdir": a.workdir,
            "namespace_id": a.namespace,
            "parent": a.parent,
            "enabled": 0,
            "repo_url": f"local:{os.path.expanduser('~/code-factory')}",
            "prompt_mode": "append",
            "last_tick_started": "",
            "last_tick_completed": "",
            "last_tick_status": "",
            "consecutive_failures": 0,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
    )
    if a.prompt:
        row["prompt"] = open(a.prompt).read()

    cols = list(row.keys())
    exists = bool(
        con.execute("SELECT 1 FROM projects WHERE name=?", (a.dst,)).fetchone()
    )
    if not exists:
        con.execute(
            f"INSERT INTO projects ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
            [row[c] for c in cols],
        )
        print(f"created {a.dst} (cloned from {a.src})")
    else:
        upd = [c for c in cols if c != "name"]
        con.execute(
            f"UPDATE projects SET {','.join(f'{c}=?' for c in upd)} WHERE name=?",
            [row[c] for c in upd] + [a.dst],
        )
        print(f"configured {a.dst}")
    con.commit()

    r = con.execute(
        "SELECT name, namespace_id, admission_mode, cooldown_floor_s, parent, "
        "length(prompt) FROM projects WHERE name=?",
        (a.dst,),
    ).fetchone()
    print("  ", dict(r))


if __name__ == "__main__":
    main()
