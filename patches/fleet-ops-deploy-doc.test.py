#!/usr/bin/env python3
"""Regression arms for SCHED-GAP-16989 — the `deploy-doc` arm must grade the DEPLOY PATH, not a
filename spelling.

Target module is argv[1] (default: the live census script). Every arm builds a throwaway fixture
tree and asks the census whether it reports `deploy-doc` there.

Two arm classes, and both are load-bearing:

  * CONVENTION arms (A/B/C) fail on the pre-fix module and pass on the fixed one — they are the
    defect. `deploy/README.md`, `docs/runbook-<topic>.md` and `INSTALL.md` are the fleet's real
    deploy-path convention and were graded as "tribal".
  * GUARD arms (D/E/F/G) must stay green on BOTH modules — a fix that also silences a repo with no
    deploy artifact, or accepts a doc buried in build output, has traded a false positive for a
    false negative and is worse than the defect.

Run:
    python3 patches/fleet-ops-deploy-doc.test.py                    # grades the live script
    python3 patches/fleet-ops-deploy-doc.test.py /path/to/copy.py   # grades any copy

Exit 0 when every arm passes, 1 otherwise.
"""

import importlib.util
import os
import shutil
import sys
import tempfile

DEFAULT = os.path.expanduser("~/.hermes/scripts/fleet_ops_check.py")


def load(path):
    spec = importlib.util.spec_from_file_location("fleet_ops_check_under_test", path)
    if spec is None or spec.loader is None:
        raise SystemExit("FAIL load: %s is not a loadable python module" % path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def fixture(tmp, name, files):
    root = os.path.join(tmp, name)
    for rel in files:
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write("# %s\n" % rel)
    os.makedirs(root, exist_ok=True)
    return root


def reports_deploy_doc(mod, root):
    return any(g["check"] == "deploy-doc" for g in mod.ops_gaps("service", root, {}))


# name, files, expect_gap  (expect_gap=False -> the deploy doc IS found)
ARMS = [
    # CONVENTION arms — fail before the fix
    (
        "A deploy/README.md beside the units",
        ["deploy/README.md", "deploy/x.service"],
        False,
    ),
    ("B docs/runbook-<topic>.md", ["docs/runbook-drain-restart.md"], False),
    ("C INSTALL.md at the root", ["INSTALL.md"], False),
    # GUARD arms — must pass before AND after
    ("D canonical docs/operations.md", ["docs/operations.md"], False),
    ("E repo with no deploy artifact", ["main.go"], True),
    (
        "F doc buried past the depth limit",
        ["vendor/third_party/deep/deploy-notes.md"],
        True,
    ),
    ("G doc inside build output", ["dist/deploy.md"], True),
]


def main(argv):
    path = argv[1] if len(argv) > 1 else DEFAULT
    mod = load(path)
    tmp = tempfile.mkdtemp(prefix="deploy-doc-arms-")
    fails = []
    try:
        for i, (name, files, expect_gap) in enumerate(ARMS, 1):
            root = fixture(tmp, "arm%d" % i, files)
            got = reports_deploy_doc(mod, root)
            ok = got == expect_gap
            want = "gap" if expect_gap else "no gap"
            print(
                "%s  %-38s want %-6s got %s"
                % ("PASS" if ok else "FAIL", name, want, "gap" if got else "no gap")
            )
            if not ok:
                fails.append(name)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("%d/%d arms passed against %s" % (len(ARMS) - len(fails), len(ARMS), path))
    if fails:
        print("failing arms: %s" % ", ".join(fails))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
