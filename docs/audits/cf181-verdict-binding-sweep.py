#!/usr/bin/env python3
"""CF-181 reproduction: does every COMPLETE row's closure verdict bind a commit on the ref?

The board census (each row's `commit_hash`) answers a different question: it grades the row's
binding, not the envelope of the verdict artifact cited as its evidence. A landing rewrite
(rebase/cherry-pick) can leave `commit_hash` correct while the verdict's `commit` names a
pre-rewrite SHA that is reachable from no branch, so a Tier-2 PASS certifies a tree that is not
the published one.

Usage: python3 docs/audits/cf181-verdict-binding-sweep.py [repo] [board-rel] [ref]
Defaults: repo=".", board=".coding-hermes/board/tasks.jsonl", ref="origin/main".

Prints one ORPHANED line per offending evidence entry, then `orphan_count=N`. Exit 0 always:
it is an instrument, not a gate. A clean board prints `orphan_count=0`.
"""

import json
import subprocess
import sys

repo = sys.argv[1] if len(sys.argv) > 1 else "."
board_rel = sys.argv[2] if len(sys.argv) > 2 else ".coding-hermes/board/tasks.jsonl"
ref = sys.argv[3] if len(sys.argv) > 3 else "origin/main"


def git(*args):
    return subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True, check=False
    )


board = git("show", f"{ref}:{board_rel}").stdout
if not board:
    print(f"FATAL: cannot read {ref}:{board_rel}")
    sys.exit(2)

rows = [json.loads(line) for line in board.splitlines() if line.strip()]
complete = [row for row in rows if row.get("status") == "complete"]

checked = 0
orphans = []
unresolved = []
malformed = []
nonverdict = 0
rows_resolving = set()
for row in complete:
    detail = row.get("detail")
    entries = detail.get("evidence", []) if isinstance(detail, dict) else []
    if not isinstance(entries, list):
        value = f" value={entries[:60]!r}" if isinstance(entries, str) else ""
        malformed.append(
            "{} evidence type={}{}".format(row["id"], type(entries).__name__, value)
        )
        continue
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            malformed.append(
                "{} evidence[{}] type={}".format(row["id"], index, type(entry).__name__)
            )
            continue
        for artifact in entry.get("artifacts") or []:
            path = artifact.split("::", 1)[0]
            if not path.endswith(".json"):
                continue
            body = git("show", f"{ref}:{path}").stdout
            if not body:
                # Pointer names a file that does not exist at the ref. Reported, never
                # swallowed: an unresolvable pointer is a missing artifact, not a pass.
                unresolved.append(
                    "{} run={} artifact={}".format(row["id"], entry.get("run_id"), path)
                )
                continue
            try:
                rec = json.loads(body)
            except json.JSONDecodeError:
                nonverdict += 1
                continue
            if not isinstance(rec, dict) or "commit" not in rec or "passed" not in rec:
                nonverdict += 1
                continue
            checked += 1
            rows_resolving.add(row["id"])
            commit = rec["commit"] or ""
            if (
                not commit
                or git("merge-base", "--is-ancestor", commit, ref).returncode != 0
            ):
                orphans.append(
                    "{} run={} artifact={} commit={} passed={}".format(
                        row["id"],
                        entry.get("run_id"),
                        path,
                        commit[:10] or "-",
                        rec.get("passed"),
                    )
                )

print(f"ref={ref} complete_rows={len(complete)}")
print(f"verdict_artifacts_checked={checked}")
print(
    f"rows_with_resolving_evidence={len(rows_resolving)} "
    f"rows_without={len(complete) - len(rows_resolving)}"
)
print("=== UNRESOLVABLE ===")
for line in unresolved:
    print(line)
print(f"unresolvable_pointers={len(unresolved)}")
print(f"non_verdict_records={nonverdict}")
print("=== MALFORMED EVIDENCE ENTRIES ===")
for line in malformed:
    print(line)
print(f"malformed_evidence_entries={len(malformed)}")
print("=== ORPHANED ===")
for line in orphans:
    print(line)
print(f"orphan_count={len(orphans)}")
print(
    "status=%s"
    % ("UNRESOLVED" if (unresolved or malformed or checked == 0) else "CLEAN")
)
