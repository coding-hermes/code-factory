#!/usr/bin/env python3
"""node_freshness.py — prove a node's checkout is the tree origin/main has.

A node is one bunker agent, one repo, one harness. Nothing in this repo measured
the *git state* of that repo: `lane_target.py --exec-bunker` proves the agent
answers and the path exists, `verify-node.sh` proves the transport and the auth
gate, and `repo_freshness.py` measures local lane workdirs from the scheduler
database only. So a node could sit one commit behind origin/main — or carry a
local edit that silently blocks its own fast-forward pull — while every layer
printed PASS (measured on cf-node, 2026-11-05: HEAD 7f22d02, origin/main
04fc398, porcelain clean, and an earlier `.gitignore` edit had blocked the pull).

This probe measures that checkout and names what is wrong with it. Four arms,
each a row with its measured value:

  branch    — an attached branch, or the detached/unborn state named
  worktree  — `git status --porcelain`; every path is printed, because an
              uncommitted edit on a node is a finding: the fix belongs upstream
  ancestor  — `git merge-base --is-ancestor HEAD origin/main`
  sync      — `git rev-list --count HEAD..origin/main` and the differing paths

Modes (exactly one):

  --workdir PATH                  a local checkout. No bunker, no network, no
                                  database: this is the mode fixtures use.
  --agent ID --server NAME        a node's checkout, probed through the agent.
      [--path REMOTE_PATH]        Defaults to `repo` relative to the agent's
                                  home, and the home is resolved FROM the agent
                                  (`echo $HOME`) inside the same exec — never
                                  templated as /home/bunker-<id>.

The whole bunker battery is ONE `bunker exec` round trip: the remote side prints
`key=value` lines and BEGIN/END blocks, the control host parses. The exec stream
dies at 300 s, so the battery is a fast read-only measurement plus one
`git fetch --quiet origin` (a ref-only update: the verdict is measured against
the remote today instead of against refs nobody refreshed).

The comparison ref is `origin/main`. A repo whose default branch is something
else is measured against `origin/HEAD` and the ref that was used is printed, so
the row never claims a comparison it did not make. A repo with no `origin`
remote is a FAIL naming that, not a crash.

Usage:
  scripts/node_freshness.py --workdir ~/repo
  scripts/node_freshness.py --agent cf-node --server bunker-las-03
  scripts/node_freshness.py --agent cf-node --server bunker-las-03 --path src/cf --json

Exit codes: 0 PASS, 1 drift or dirty, 2 usage or unreachable (an unmeasurable
node is not a PASS). With --json the rows go to stderr and one JSON object goes
to stdout, so a provisioner can store the measurement without parsing prose.

stdlib + the git CLI only.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Optional

GIT_BIN = shutil.which("git") or "git"
BUNKER_BIN = shutil.which("bunker") or "bunker"

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_USAGE = 2

# The ref a node's checkout is held to. Anything else is only a fallback that
# the rows name explicitly.
CMP_REF = "origin/main"

# A drifted node can differ in hundreds of paths; print enough to act on and
# point at --json for the rest. The lag count is always printed in full.
MAX_SHOWN = 50


class Res:
    """One command's result. A timeout and a missing binary are results too."""

    __slots__ = ("rc", "out", "err")

    def __init__(self, rc: int, out: str, err: str) -> None:
        self.rc = rc
        self.out = out
        self.err = err

    @property
    def ok(self) -> bool:
        return self.rc == 0

    def text(self) -> str:
        return (self.out or "").strip()

    def first_err(self) -> str:
        text = (self.err or "").strip() or (self.out or "").strip()
        for line in text.splitlines():
            if line.strip():
                return line.strip()[:300]
        return f"exit {self.rc}"


def git_env() -> dict:
    """A git that never prompts: a probe must not hang on a credential dialog."""
    env = dict(os.environ)
    env.update(
        {
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_SSH_COMMAND": env.get("GIT_SSH_COMMAND")
            or "ssh -o BatchMode=yes -o ConnectTimeout=10",
            "LC_ALL": "C",
            "LANG": "C",
        }
    )
    return env


def run(cmd: list, timeout: int) -> Res:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=git_env(),
            check=False,
        )
    except subprocess.TimeoutExpired:
        return Res(-9, "", f"timeout after {timeout}s: {' '.join(cmd[:4])}")
    except OSError as exc:
        return Res(-1, "", f"{type(exc).__name__}: {exc}")
    return Res(proc.returncode, proc.stdout, proc.stderr)


def git(root: str, *args: str, timeout: int = 60) -> Res:
    return run([GIT_BIN, "-C", root, *args], timeout)


def shq(value: str) -> str:
    """One value quoted for a remote POSIX shell, apostrophes included."""
    return "'" + value.replace("'", "'\\''") + "'"


def strip_status(lines: list) -> list:
    """`git status --porcelain` -> the paths, without the 3-char status prefix.

    Entry format is XY<space>PATH (or `XY ORIG -> PATH` for a rename). The row
    has to name files an operator can act on, so the status letters go away and
    a rename keeps its arrow.
    """
    out = []
    for line in lines:
        if not line.strip():
            continue
        path = line[3:] if len(line) > 3 else line.strip()
        out.append(path.strip())
    return out


@dataclass
class Measurement:
    """What was measured, before any judgement. Both modes fill this in."""

    mode: str = "local"
    target: str = ""  # workdir path, or the agent's resolved checkout
    agent: str = ""
    server: str = ""
    home: str = ""
    path: str = ""
    exists: bool = True
    is_git: bool = True
    bare: bool = False
    branch: str = ""
    head: str = ""
    comparison_ref: str = ""
    origin_main: str = ""
    has_origin: bool = True
    remotes: list = field(default_factory=list)
    ancestor: Optional[bool] = None
    behind: Optional[int] = None
    dirty_files: list = field(default_factory=list)
    differing_files: list = field(default_factory=list)
    fetch_error: str = ""
    error: str = ""  # set when nothing could be measured
    error_kind: str = ""  # "unreachable" (exit 2) or a checkout finding


@dataclass
class Row:
    status: str
    check: str
    value: str


@dataclass
class Finding:
    rows: list
    status: str = "PASS"
    reason: str = ""
    exit_code: int = EXIT_OK
    kind: str = ""

    @property
    def result(self) -> str:
        return "PASS" if self.status == "PASS" else f"FAIL ({self.reason})"


def named(items: list, cap: int = MAX_SHOWN) -> str:
    """Render a path list for a single row, with an honest truncation marker."""
    if not items:
        return "none"
    shown = ", ".join(items[:cap])
    if len(items) > cap:
        shown += f" (+{len(items) - cap} more, see --json)"
    return shown


def classify(m: Measurement) -> Finding:
    """Turn one measurement into rows and a verdict.

    Every arm that could be measured gets its own row, so a dirty-and-behind
    checkout reports both rather than only the first one found. The arms are
    independent on purpose: an operator needs the whole state, not its first
    symptom.
    """
    rows: list = []

    def add(status: str, check: str, value: str) -> None:
        rows.append(Row(status, check, value))

    # Nothing measured at all: usage or an agent that would not answer.
    if m.error_kind == "unreachable":
        add("FAIL", "unreachable", m.error)
        return Finding(rows, "FAIL", m.error, EXIT_USAGE, "unreachable")

    if not m.exists:
        where = f" on agent {m.agent}" if m.mode == "bunker" else ""
        add(
            "FAIL",
            "checkout",
            f"{m.path or '(unknown path)'} does not exist{where} — "
            f"there is no tree to measure",
        )
        return Finding(
            rows,
            "FAIL",
            f"no checkout at {m.path or '(unknown path)'}",
            EXIT_DRIFT,
            "no-checkout",
        )
    if not m.is_git:
        add(
            "FAIL",
            "checkout",
            f"{m.path} is not a git checkout ({m.error or 'no work tree'}) — "
            f"a node cannot work a tree it cannot fast-forward",
        )
        return Finding(
            rows, "FAIL", f"{m.path} is not a git checkout", EXIT_DRIFT, "not-git"
        )

    failures: list = []

    # 1. an attached branch: a detached HEAD cannot be fast-forwarded or pushed
    if m.branch and m.branch != "HEAD":
        add("PASS", "branch", f"branch={m.branch}")
    else:
        state = (
            f"detached HEAD at {m.head[:12]}" if m.head else "unborn HEAD (no commits)"
        )
        add("FAIL", "branch", f"{state} — no attached branch to fast-forward")
        failures.append(state)

    # 2. uncommitted work: a local edit on a node blocks its own pull, and the
    #    fix belongs upstream, not in the node's tree
    if m.dirty_files:
        add(
            "FAIL",
            "worktree",
            f"{len(m.dirty_files)} uncommitted path(s): {named(m.dirty_files)} — "
            f"a local edit on the node blocks its fast-forward; the fix belongs upstream",
        )
        failures.append(f"{len(m.dirty_files)} uncommitted path(s)")
    else:
        add("PASS", "worktree", "0 uncommitted paths")

    # Without origin there is nothing to compare against: FAIL naming that.
    if not m.has_origin:
        add(
            "FAIL",
            "origin",
            f"no 'origin' remote (remotes: {', '.join(m.remotes) or 'none'}) — "
            f"cannot compare against {CMP_REF}",
        )
        failures.append("no origin remote")
        return Finding(rows, "FAIL", "; ".join(failures), EXIT_DRIFT, "no-origin")

    ref = m.comparison_ref or CMP_REF
    ref_note = "" if ref == CMP_REF else f" ({ref} is this repo's default branch)"
    origin_sha = m.origin_main[:12] if m.origin_main else "(unresolved)"

    # 3. ancestry: HEAD must be behind or equal to origin/main, never beside it
    if m.ancestor is True:
        add(
            "PASS",
            "ancestor",
            f"HEAD {m.head[:12] or '(unknown)'} is an ancestor of {ref} "
            f"{origin_sha}{ref_note}",
        )
    elif m.ancestor is False:
        add(
            "FAIL",
            "ancestor",
            f"HEAD {m.head[:12] or '(unknown)'} is NOT an ancestor of {ref} "
            f"{origin_sha}{ref_note} — the checkout has diverged",
        )
        failures.append(f"diverged from {ref}")
    else:
        add(
            "FAIL",
            "ancestor",
            f"ancestry of HEAD against {ref} could not be measured "
            f"({m.error or 'no comparison ref'})",
        )
        failures.append(f"ancestry against {ref} unmeasurable")

    # 4. lag: how many commits, and which files differ
    if m.behind is None:
        add(
            "FAIL",
            "sync",
            f"lag against {ref} could not be counted ({m.error or 'no comparison ref'})",
        )
        failures.append(f"lag against {ref} unmeasurable")
    elif m.behind > 0:
        add(
            "FAIL",
            "sync",
            f"behind={m.behind} (HEAD..{ref} {origin_sha}): "
            f"{len(m.differing_files)} differing path(s) — {named(m.differing_files)}",
        )
        failures.append(f"behind {m.behind} commit(s) vs {ref}")
    else:
        add("PASS", "sync", f"behind=0 (HEAD..{ref} {origin_sha})")

    if m.fetch_error and m.behind is not None and m.behind == 0:
        # The comparison ref is only as fresh as the fetch. A checkout that
        # matches last-known origin/main is not proof it matches the remote
        # today, so this is named rather than passed off as freshness.
        add(
            "FAIL",
            "fetch",
            f"git fetch origin failed: {m.fetch_error} — the comparison ref may be stale",
        )
        failures.append("origin unreachable (lag counted from stale refs)")

    if failures:
        return Finding(rows, "FAIL", "; ".join(failures), EXIT_DRIFT, "drift")

    add(
        "PASS",
        "freshness",
        f"branch={m.branch} head={m.head[:12]} origin_main={m.origin_main[:12]} "
        f"ancestor=true behind=0",
    )
    return Finding(rows, "PASS", "", EXIT_OK, "fresh")


# --------------------------------------------------------------- local mode


def probe_local(path: str, timeout: int) -> Measurement:
    """Measure a local checkout with the git CLI only."""
    m = Measurement(mode="local", target=path, path=path)
    root = os.path.expanduser(path.strip())

    if not root:
        m.exists = False
        m.error = "empty workdir path"
        return m
    if not os.path.exists(root):
        m.exists = False
        m.error = f"{root} does not exist"
        return m
    if not os.path.isdir(root):
        m.exists = False
        m.error = f"{root} is not a directory"
        return m

    # A bare repo has no work tree, so --show-toplevel fails on it. Ask the
    # bare question first or every bare checkout would read as "not git".
    bare = git(root, "rev-parse", "--is-bare-repository", timeout=timeout)
    if bare.ok and bare.text() == "true":
        m.is_git = False
        m.bare = True
        m.error = "bare repository: no work tree"
        return m
    top = git(root, "rev-parse", "--show-toplevel", timeout=timeout)
    if not top.ok:
        m.is_git = False
        m.error = top.first_err()
        return m
    m.path = top.text()

    m.remotes = [n for n in git(root, "remote", timeout=timeout).text().split() if n]
    m.has_origin = "origin" in m.remotes

    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD", timeout=timeout)
    m.branch = branch.text() if branch.ok else ""
    head = git(root, "rev-parse", "--verify", "HEAD", timeout=timeout)
    m.head = head.text() if head.ok else ""

    status = git(root, "status", "--porcelain", timeout=timeout)
    if status.ok:
        m.dirty_files = strip_status(status.out.splitlines())
    else:
        m.error = f"git status failed: {status.first_err()}"

    if not m.has_origin:
        return m

    fetch = git(root, "fetch", "--quiet", "--no-tags", "origin", timeout=timeout)
    if not fetch.ok:
        m.fetch_error = fetch.first_err()

    ref, sha, err = resolve_comparison_ref(lambda *a: git(root, *a, timeout=timeout))
    m.comparison_ref, m.origin_main = ref, sha
    if not ref:
        m.error = err
        return m

    ancestor = git(root, "merge-base", "--is-ancestor", "HEAD", ref, timeout=timeout)
    if ancestor.rc == 0:
        m.ancestor = True
    elif ancestor.rc == 1:
        m.ancestor = False
    else:
        m.ancestor = None
        m.error = ancestor.first_err()

    behind = git(root, "rev-list", "--count", f"HEAD..{ref}", timeout=timeout)
    if behind.ok and behind.text().isdigit():
        m.behind = int(behind.text())
    diff = git(root, "diff", "--name-only", "HEAD", ref, timeout=timeout)
    if diff.ok:
        m.differing_files = [p for p in diff.out.splitlines() if p.strip()]
    return m


def resolve_comparison_ref(gitfn) -> tuple:
    """Return (ref, sha, error): origin/main, else origin/HEAD's target."""
    sha = gitfn("rev-parse", "--verify", "--quiet", CMP_REF)
    if sha.ok and sha.text():
        return CMP_REF, sha.text(), ""
    symbolic = gitfn("rev-parse", "--abbrev-ref", "--symbolic-full-name", "origin/HEAD")
    candidate = symbolic.text() if symbolic.ok else ""
    if (
        candidate
        and candidate not in ("origin/HEAD", "HEAD")
        and candidate.startswith("origin/")
    ):
        sha = gitfn("rev-parse", "--verify", "--quiet", candidate)
        if sha.ok and sha.text():
            return candidate, sha.text(), ""
    return "", "", f"no {CMP_REF} and no origin/HEAD on the checkout"


# -------------------------------------------------------------- bunker mode


REMOTE_BATTERY = r"""
set -u
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"
REPO_ARG=__PATH__
echo "HOME=$HOME"
case "$REPO_ARG" in
  /*) REPO="$REPO_ARG" ;;
  '~/'*) REPO="$HOME/${REPO_ARG#\~/}" ;;
  *) REPO="$HOME/$REPO_ARG" ;;
esac
echo "REPO=$REPO"
if [ ! -d "$REPO" ]; then echo "EXISTS=0"; exit 0; fi
echo "EXISTS=1"
cd "$REPO" || { echo "CD=0"; exit 0; }
echo "CD=1"
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
  echo "BARE=$(git rev-parse --is-bare-repository 2>/dev/null)"
  exit 0
fi
echo "IS_GIT=1"
echo "BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
echo "HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)"
echo "REMOTES=$(git remote 2>/dev/null | tr '\n' ' ')"
echo "DIRTY_BEGIN"
git status --porcelain 2>/dev/null
echo "DIRTY_END"
if command -v timeout >/dev/null 2>&1; then
  timeout 120 git fetch --quiet --no-tags origin >/dev/null 2>&1
else
  git fetch --quiet --no-tags origin >/dev/null 2>&1
fi
echo "FETCH_RC=$?"
CMP=""
if git rev-parse --verify --quiet __CMP__ >/dev/null 2>&1; then
  CMP=__CMP__
else
  CAND="$(git rev-parse --abbrev-ref --symbolic-full-name origin/HEAD 2>/dev/null)"
  case "$CAND" in origin/*HEAD*|"") CAND="" ;; esac
  CMP="$CAND"
fi
echo "CMP_REF=$CMP"
if [ -n "$CMP" ]; then
  echo "ORIGIN_MAIN=$(git rev-parse --verify --quiet "$CMP" 2>/dev/null)"
  git merge-base --is-ancestor HEAD "$CMP" >/dev/null 2>&1
  echo "ANCESTOR_RC=$?"
  echo "BEHIND=$(git rev-list --count "HEAD..$CMP" 2>/dev/null)"
  echo "DIFF_BEGIN"
  git diff --name-only HEAD "$CMP" 2>/dev/null
  echo "DIFF_END"
fi
"""


def parse_battery(text: str) -> dict:
    """Parse the remote `key=value` lines and the two BEGIN/END blocks."""
    data: dict = {"blocks": {"DIRTY": [], "DIFF": []}}
    block = ""
    for line in text.splitlines():
        if line in ("DIRTY_BEGIN", "DIFF_BEGIN"):
            block = line.split("_", 1)[0]
            continue
        if line in ("DIRTY_END", "DIFF_END"):
            block = ""
            continue
        if block:
            data["blocks"][block].append(line)
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            # Only our own constants are `KEY=...`; anything else is remote text
            # (git chatter) and must not be mistaken for a measurement.
            if key.isupper() and key == key.strip():
                data[key] = value
    return data


def probe_bunker(agent: str, server: str, path_arg: str, timeout: int) -> Measurement:
    """Measure a node's checkout in ONE `bunker exec` round trip."""
    m = Measurement(
        mode="bunker",
        agent=agent,
        server=server,
        path=path_arg,
        target=f"{agent}:{path_arg}",
    )
    script = REMOTE_BATTERY.replace("__PATH__", shq(path_arg)).replace(
        "__CMP__", CMP_REF
    )
    res = run(
        [BUNKER_BIN, "--server", server, "exec", agent, "--", "sh", "-lc", script],
        timeout,
    )
    if not res.ok:
        m.error_kind = "unreachable"
        m.error = f"bunker exec failed: {res.first_err()}"
        return m

    data = parse_battery(res.out)
    m.home = data.get("HOME", "")
    m.path = data.get("REPO", "") or (f"{m.home}/{path_arg}" if m.home else path_arg)
    if not m.home:
        # No home means the exec answered with something that is not our
        # battery (or the stream was cut): nothing about the checkout is known.
        m.error_kind = "unreachable"
        m.error = (
            f"bunker exec returned no HOME (first line: "
            f"{(res.out.strip().splitlines() or ['(empty)'])[0][:160]})"
        )
        return m

    if data.get("EXISTS") != "1":
        m.exists = False
        m.error = f"{m.path} does not exist on agent {agent}"
        return m
    if data.get("CD") != "1":
        m.error_kind = "unreachable"
        m.error = f"cannot enter {m.path} on agent {agent} (cd failed)"
        return m
    if data.get("IS_GIT") != "1":
        m.is_git = False
        m.bare = data.get("BARE", "") == "true"
        m.error = "bare repository: no work tree" if m.bare else "no git work tree"
        return m

    m.branch = data.get("BRANCH", "")
    m.head = data.get("HEAD_SHA", "")
    m.remotes = [n for n in (data.get("REMOTES", "") or "").split() if n]
    m.has_origin = "origin" in m.remotes
    m.dirty_files = strip_status(data["blocks"]["DIRTY"])

    if data.get("FETCH_RC") not in (None, "0"):
        m.fetch_error = f"git fetch exited {data.get('FETCH_RC')}"
    if not m.has_origin:
        return m

    m.comparison_ref = data.get("CMP_REF", "")
    m.origin_main = data.get("ORIGIN_MAIN", "")
    if not m.comparison_ref:
        m.error = f"no {CMP_REF} and no origin/HEAD on the checkout"
        return m
    anc = data.get("ANCESTOR_RC")
    if anc == "0":
        m.ancestor = True
    elif anc == "1":
        m.ancestor = False
    behind = data.get("BEHIND", "")
    if behind.isdigit():
        m.behind = int(behind)
    m.differing_files = [p for p in data["blocks"]["DIFF"] if p.strip()]
    return m


# ------------------------------------------------------------------- report


def header(m: Measurement) -> str:
    if m.mode == "bunker":
        return (
            f"node-freshness — agent {m.agent} via {m.server}, "
            f"checkout {m.path or '(unresolved)'} (home {m.home or '(unresolved)'})"
        )
    return f"node-freshness — workdir {m.path}"


def as_dict(m: Measurement, f: Finding) -> dict:
    """The object a provisioner stores. Keys the manifest names come first."""
    return {
        "mode": m.mode,
        "status": f.status,
        "result": f.result,
        "reason": f.reason,
        "kind": f.kind,
        "exit_code": f.exit_code,
        "agent": m.agent,
        "server": m.server,
        "home": m.home,
        "path": m.path,
        "branch": m.branch,
        "head": m.head,
        "origin_main": m.origin_main,
        "comparison_ref": m.comparison_ref,
        "ancestor": m.ancestor,
        "behind": m.behind,
        "dirty_files": m.dirty_files,
        "differing_files": m.differing_files,
        "remotes": m.remotes,
        "fetch_error": m.fetch_error,
        "error": m.error,
        "rows": [
            {"status": r.status, "check": r.check, "value": r.value} for r in f.rows
        ],
    }


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(
        description="prove a node's checkout is the tree origin/main has"
    )
    ap.add_argument("--workdir", metavar="PATH", help="measure a local checkout")
    ap.add_argument("--agent", metavar="ID", help="bunker agent id (bunker mode)")
    ap.add_argument("--server", metavar="NAME", help="bunker server name (bunker mode)")
    ap.add_argument(
        "--path",
        default="repo",
        metavar="REMOTE_PATH",
        help="path inside the agent, relative to its home (default: repo)",
    )
    ap.add_argument(
        "--timeout",
        type=int,
        default=180,
        help="per-command timeout in seconds; the bunker exec stream dies at 300 (default 180)",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="emit one JSON object on stdout (rows go to stderr)",
    )
    opts = ap.parse_args(argv)

    def usage_error(message: str) -> int:
        print(message, file=sys.stderr)
        print(f"RESULT: FAIL (usage: {message})")
        return EXIT_USAGE

    if opts.timeout < 1:
        return usage_error(f"--timeout must be >= 1, got {opts.timeout}")
    local = bool(opts.workdir)
    bunker = bool(opts.agent or opts.server)
    if local and bunker:
        return usage_error("--workdir and --agent/--server are exclusive")
    if not local and not bunker:
        return usage_error(
            "one mode is required: --workdir PATH or --agent ID --server NAME"
        )
    if bunker and not (opts.agent and opts.server):
        return usage_error("bunker mode needs both --agent ID and --server NAME")

    if local:
        m = probe_local(opts.workdir, opts.timeout)
    else:
        m = probe_bunker(opts.agent, opts.server, opts.path, opts.timeout)
    finding = classify(m)

    stream = sys.stderr if opts.json else sys.stdout
    print(header(m), file=stream)
    for row in finding.rows:
        print(f"  {row.status}  {row.check} — {row.value}", file=stream)
    print(f"RESULT: {finding.result}", file=stream)

    if opts.json:
        print(json.dumps(as_dict(m, finding), indent=2))
    return finding.exit_code


if __name__ == "__main__":
    sys.exit(main())
