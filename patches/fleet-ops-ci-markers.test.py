#!/usr/bin/env python3
"""Fixture harness for FLEET-OPS-CI-001 — the fleet ops census must recognize non-GitHub CI.

The file under test (`~/.hermes/scripts/fleet_ops_check.py`) lives outside this repository and has
no version history, so its regression proof ships next to its patch instead of inside
`tests/selftest.sh` (which cannot import a script that is not in the tree).

  python3 patches/fleet-ops-ci-markers.test.py [path-to-fleet_ops_check.py]

Every arm prints `PASS`/`FAIL` beside what it measured; the process exits 1 if any arm fails.

Defect this locks shut
----------------------
`ops_gaps()` tested only `rel_hits(root, ('.github',), 1)` before emitting the P3
"no CI pipeline in the repo — nothing gates a merge". A repo whose pipeline is configured in
`.gitlab-ci.yml` (asce, heading) therefore reported a gap that no amount of work could close,
because the pipeline already existed and ran.

Arms
----
  A. service + .gitlab-ci.yml            -> NO ci gap
  B. service + .github/workflows/ci.yml  -> NO ci gap (the original behaviour must survive)
  C. service + .circleci/config.yml      -> NO ci gap
  D. service + Jenkinsfile               -> NO ci gap
  E. service + azure-pipelines.yml       -> NO ci gap
  F. service + nothing                   -> ci gap PRESENT  (negative control: check is alive)
  G. docs kind + .gitlab-ci.yml          -> NO ci gap (kind gate unchanged)
  H. live check: a real GitLab-CI repo reports no ci gap (skipped when the path is absent)
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile

TARGET = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.expanduser("~/.hermes/scripts/fleet_ops_check.py")
)

results: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, detail: str) -> None:
    results.append((name, ok, detail))
    print(("PASS" if ok else "FAIL") + f"  {name}: {detail}")


def load_module():
    spec = importlib.util.spec_from_file_location("fleet_ops_check_under_test", TARGET)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def ci_gap(mod, kind: str, root: str) -> bool:
    return any(g["check"] == "ci" for g in mod.ops_gaps(kind, root, {}))


def tree(files: dict[str, str]) -> str:
    root = tempfile.mkdtemp(prefix="fleet-ops-ci-")
    for rel, body in files.items():
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True) if os.path.dirname(p) else None
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(body)
    return root


def main() -> int:
    if not os.path.exists(TARGET):
        print(f"FAIL  target not found: {TARGET}")
        return 1
    mod = load_module()
    print(f"target: {TARGET}")

    flat = {"main.go": "package main\n"}

    gitlab = tree(
        {**flat, ".gitlab-ci.yml": "stages: [test]\ntest:\n  script: [true]\n"}
    )
    record(
        "A gitlab-ci",
        not ci_gap(mod, "service", gitlab),
        f"ci gap emitted = {ci_gap(mod, 'service', gitlab)} (want False)",
    )

    gha = tree(
        {
            **flat,
            ".github/workflows/ci.yml": "on: [push]\njobs: {t: {runs-on: ubuntu-latest, steps: []}}\n",
        }
    )
    record(
        "B github actions",
        not ci_gap(mod, "service", gha),
        f"ci gap emitted = {ci_gap(mod, 'service', gha)} (want False)",
    )

    circle = tree({**flat, ".circleci/config.yml": "version: 2.1\n"})
    record(
        "C circleci",
        not ci_gap(mod, "service", circle),
        f"ci gap emitted = {ci_gap(mod, 'service', circle)} (want False)",
    )

    jenkins = tree({**flat, "Jenkinsfile": "pipeline { agent any }\n"})
    record(
        "D jenkins",
        not ci_gap(mod, "service", jenkins),
        f"ci gap emitted = {ci_gap(mod, 'service', jenkins)} (want False)",
    )

    azure = tree({**flat, "azure-pipelines.yml": "trigger: [main]\n"})
    record(
        "E azure",
        not ci_gap(mod, "service", azure),
        f"ci gap emitted = {ci_gap(mod, 'service', azure)} (want False)",
    )

    bare = tree(flat)
    record(
        "F negative control (no CI)",
        ci_gap(mod, "service", bare),
        f"ci gap emitted = {ci_gap(mod, 'service', bare)} (want True)",
    )

    docs = tree({"README.md": "# docs\n", ".gitlab-ci.yml": "stages: [test]\n"})
    record(
        "G docs kind untouched",
        not ci_gap(mod, "docs", docs),
        f"ci gap emitted = {ci_gap(mod, 'docs', docs)} (want False)",
    )

    live = os.path.expanduser("/home/kara/asce")
    if os.path.isdir(os.path.join(live, ".git")) and os.path.exists(
        os.path.join(live, ".gitlab-ci.yml")
    ):
        record(
            "H live asce repo",
            not ci_gap(mod, "service", live),
            f"ci gap emitted = {ci_gap(mod, 'service', live)} (want False)",
        )
    else:
        print("SKIP  H live asce repo: fixture path absent on this host")

    failed = [r for r in results if not r[1]]
    print(f"\n{len(results) - len(failed)}/{len(results)} arms passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
