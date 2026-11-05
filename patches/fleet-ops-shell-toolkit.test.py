#!/usr/bin/env python3
"""Fixture harness for CF-206 — the fleet ops census must classify a shell toolkit as `cli`.

The file under test (`~/.hermes/scripts/fleet_ops_check.py`) lives outside this repository and has
no version history, so its regression proof ships next to its patch instead of inside
`tests/selftest.sh` (which cannot import a script that is not in the tree).

  python3 patches/fleet-ops-shell-toolkit.test.py [path-to-fleet_ops_check.py]

Every arm prints `PASS`/`FAIL` beside what it measured; the process exits 1 if any arm fails.

Arms
----
  A. docs tree (only docs/*.md, no scripts)                         -> docs
  B. go.mod + cmd/                                                 -> cli
  C. package.json + Dockerfile                                     -> service
  D. manifest-less tree with scripts/a.sh + scripts/b.sh            -> cli, basis shell-toolkit:2
  E. same tree as a git repo where the scripts are UNTRACKED        -> docs (ships no toolkit)
  F. one script and no tests/selftest.sh gate                       -> docs (below the threshold)
  G. census rc semantics: one clean family                          -> 0
  H. census rc semantics: one family with an ops gap                -> 1
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.expanduser("~/.hermes/scripts/fleet_ops_check.py")
)

results: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, measured: str) -> None:
    results.append((name, ok, measured))
    print("%-42s %-4s  %s" % (name, "PASS" if ok else "FAIL", measured))


def load(root: str):
    spec = importlib.util.spec_from_file_location("fleet_ops_check_under_test", root)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def write(path: str, body: str = "x\n") -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(body)


def main() -> int:
    if not os.path.exists(TARGET):
        print("FAIL: target not found: %s" % TARGET)
        return 1
    mod = load(TARGET)
    F = tempfile.mkdtemp(prefix="cf206-fixtures.")

    docs_tree = os.path.join(F, "a-docs")
    write(os.path.join(docs_tree, "docs", "DESIGN.md"), "# design\n")
    write(os.path.join(docs_tree, "docs", "SPEC.md"), "# spec\n")
    go_cli = os.path.join(F, "b-go-cli")
    write(os.path.join(go_cli, "go.mod"), "module fixture\n")
    write(
        os.path.join(go_cli, "cmd", "fixture", "main.go"),
        "package main\n\nfunc main() {}\n",
    )
    svc = os.path.join(F, "c-service")
    write(os.path.join(svc, "package.json"), '{"name":"fixture"}\n')
    write(os.path.join(svc, "Dockerfile"), "FROM scratch\n")
    toolkit = os.path.join(F, "d-toolkit")
    write(os.path.join(toolkit, "scripts", "a.sh"), "#!/bin/sh\n")
    write(os.path.join(toolkit, "scripts", "b.sh"), "#!/bin/sh\n")
    git_toolkit = os.path.join(F, "e-untracked-toolkit")
    write(os.path.join(git_toolkit, "scripts", "a.sh"), "#!/bin/sh\n")
    write(os.path.join(git_toolkit, "scripts", "b.sh"), "#!/bin/sh\n")
    write(os.path.join(git_toolkit, "README.md"), "# readme\n")
    subprocess.run(["git", "init", "-q", git_toolkit], check=True)
    subprocess.run(["git", "-C", git_toolkit, "add", "README.md"], check=True)
    subprocess.run(
        [
            "git",
            "-C",
            git_toolkit,
            "-c",
            "user.name=f",
            "-c",
            "user.email=f@f",
            "commit",
            "-qm",
            "fixture",
        ],
        check=True,
    )
    one_script = os.path.join(F, "f-one-script")
    write(os.path.join(one_script, "docs", "SPEC.md"), "# spec\n")
    write(os.path.join(one_script, "scripts", "a.sh"), "#!/bin/sh\n")
    toolkit_doc = os.path.join(F, "i-toolkit-doc")
    write(os.path.join(toolkit_doc, "scripts", "a.sh"), "#!/bin/sh\n")
    write(os.path.join(toolkit_doc, "scripts", "b.sh"), "#!/bin/sh\n")
    write(os.path.join(toolkit_doc, "docs", "OPERATIONS.md"), "# ops\n")

    def docs_only(path: str) -> bool:
        return not any(
            os.path.exists(os.path.join(path, f))
            for f in (
                "go.mod",
                "package.json",
                "pyproject.toml",
                "setup.py",
                "Cargo.toml",
                "requirements.txt",
            )
        )

    arms = [
        ("A docs tree -> docs", docs_tree, "docs"),
        ("B go.mod+cmd -> cli", go_cli, "cli"),
        ("C package.json+Dockerfile -> service", svc, "service"),
        ("D shell toolkit -> cli", toolkit, "cli"),
        ("E untracked scripts -> docs", git_toolkit, "docs"),
        ("F one script, no gate -> docs", one_script, "docs"),
    ]
    for name, path, want in arms:
        kind, ev = mod.classify(path, docs_only(path))
        record(name, kind == want, "kind=%s (want %s)" % (kind, want))

    kind, ev = mod.classify(toolkit, True)
    record(
        "D basis names the script count",
        str(ev.get("kind_basis", "")).startswith("shell-toolkit:2"),
        "kind_basis=%s" % ev.get("kind_basis"),
    )

    kind, ev = mod.classify(toolkit_doc, True)
    gaps_i = mod.ops_gaps(kind, toolkit_doc, ev)
    record(
        "I docs/OPERATIONS.md uppercase -> no gap",
        kind == "cli" and not gaps_i,
        "kind=%s gaps=%s" % (kind, [g["check"] for g in gaps_i]),
    )

    # ---- census exit-code semantics (rc=0 clean, rc=1 when a family has a gap) ----
    db = os.path.join(F, "scheduler.db")
    con = sqlite3.connect(db)
    con.execute(
        "CREATE TABLE projects (name TEXT, workdir TEXT, repo_url TEXT, "
        "enabled INTEGER, namespace_id TEXT)"
    )
    con.execute(
        "INSERT INTO projects VALUES (?,?,?,?,?)",
        ("fixA", docs_tree, "local:" + docs_tree, 0, "ns"),
    )
    con.commit()
    con.close()

    mod.DB = db
    buf = io.StringIO()
    sys.argv = ["fleet_ops_check.py", "--json"]
    with redirect_stdout(buf):
        rc_clean = mod.main()
    payload = json.loads(buf.getvalue())
    record(
        "G rc=0, no family has a gap",
        rc_clean == 0 and payload[0]["gaps"] == [],
        "rc=%d gaps=%d" % (rc_clean, len(payload[0]["gaps"])),
    )

    con = sqlite3.connect(db)
    con.execute("DELETE FROM projects")
    con.execute(
        "INSERT INTO projects VALUES (?,?,?,?,?)",
        ("fixB", go_cli, "local:" + go_cli, 0, "ns"),
    )
    con.commit()
    con.close()
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc_gap = mod.main()
    payload = json.loads(buf.getvalue())
    gap_names = [g["check"] for g in payload[0]["gaps"]]
    record(
        "H rc=1, a family has a gap",
        rc_gap == 1 and gap_names == ["deploy-doc"],
        "rc=%d gaps=%s" % (rc_gap, gap_names),
    )

    failed = [r for r in results if not r[1]]
    print(
        "\nRESULT: %s (%d/%d arms)"
        % ("PASS" if not failed else "FAIL", len(results) - len(failed), len(results))
    )
    print("fixtures kept at %s (scratch, prunable)" % F)
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
