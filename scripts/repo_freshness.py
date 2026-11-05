#!/usr/bin/env python3
"""repo_freshness.py — measure how far each lane workdir has drifted from its remote.

The scheduler dispatches a lane into a local workdir, and nothing refreshes that
checkout afterwards. A lane can therefore work a tree that is months behind its
remote: every row it files is measured against a stale world, and the control
host only finds out when a merge conflict is the first symptom. This probe
measures the drift, names the number, and refuses to let a caller dispatch into
a stale tree.

Per workdir it:

  1. resolves the checkout — real path, git top level, bare and unborn detection;
  2. resolves the comparison ref — the branch's upstream, or <remote>/<branch>
     when no upstream is configured, or <remote>/HEAD for a detached HEAD;
  3. refreshes the remote-tracking refs (`git fetch`, on by default; `--no-fetch`
     measures only what the local refs already know);
  4. counts `git rev-list --count HEAD..<ref>` (lag) and the reverse count
     (ahead), and reports the age of the last fetch from FETCH_HEAD's mtime;
  5. prints one PASS / WARN / FAIL row naming the measured value.

Workdirs come from the scheduler's sqlite `projects` table (`enabled = 1`), never
from a hand-written list, so a lane added to the fleet is covered on the next run
and a lane removed from it stops being probed. `--workdir PATH` probes explicit
paths and never opens the database.

Defects that are tolerated as named rows, never as a crash: a missing workdir, a
workdir that is not a directory, a non-git workdir, a bare repository, an unborn
HEAD, a detached HEAD and a branch with no upstream. An unmeasurable workdir is
WARN, because "cannot measure" is not proof of staleness; `--strict` escalates
every WARN to FAIL so a gate can refuse on "unknown" as well as on "behind".

Staleness bound: `--bound N` (default 0, any commit behind is stale). A workdir
more than N commits behind prints FAIL naming the lag. `--gate` makes the
process exit non-zero, so a dispatcher refuses the tick:

    scripts/repo_freshness.py --gate || exit 1

Usage:
  scripts/repo_freshness.py                        # whole fleet, fetch, gate off
  scripts/repo_freshness.py --gate --bound 3       # refuse if any lane is >3 behind
  scripts/repo_freshness.py --workdir ~/crier --no-fetch
  scripts/repo_freshness.py --json

Exit codes: 0 ok (stale rows without --gate still exit 0), 1 gate failed,
2 config error (unreadable database, bad arguments).

stdlib + the git CLI only. The only network call is the fetch it reports.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

GIT_BIN = shutil.which("git") or "git"
DEFAULT_DB = "~/.hermes/coding-hermes/scheduler.db"
DB_ENV = "CF_SCHEDULER_DB"

EXIT_OK = 0
EXIT_GATE = 1
EXIT_CONFIG = 2

# A missing / non-git / bare / unborn / no-upstream workdir is unmeasurable, not
# stale. These statuses keep it visible without pretending to know its lag.
UNMEASURABLE = "WARN"


class ConfigError(RuntimeError):
    """An argument or database problem: reported as a FAIL row, exit 2."""


@dataclass
class GitResult:
    rc: int
    out: str
    err: str

    @property
    def ok(self) -> bool:
        return self.rc == 0

    def first_err(self) -> str:
        text = (self.err or "").strip() or (self.out or "").strip()
        for line in text.splitlines():
            if line.strip():
                return line.strip()[:200]
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


def git(root: str, *args: str, timeout: int = 60) -> GitResult:
    """Run one git command in `root`, converting a timeout into a result."""
    cmd = [GIT_BIN, "-C", root, *args]
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
        return GitResult(-9, "", f"timeout after {timeout}s: git {' '.join(args)}")
    except OSError as exc:
        return GitResult(-1, "", f"{type(exc).__name__}: {exc}")
    return GitResult(proc.returncode, proc.stdout, proc.stderr)


def human_age(seconds: float) -> str:
    if seconds < 0:
        return "in the future"
    if seconds < 90:
        return f"{int(seconds)}s"
    if seconds < 5400:
        return f"{seconds / 60:.0f}m"
    if seconds < 172800:
        return f"{seconds / 3600:.1f}h"
    return f"{seconds / 86400:.1f}d"


def iso_utc(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


@dataclass
class Probe:
    """One workdir's measurement. `status` is the row that will be printed."""

    name: str
    workdir: str
    status: str = "PASS"
    value: str = ""
    lag: Optional[int] = None
    ahead: Optional[int] = None
    branch: str = ""
    target_ref: str = ""
    detached: bool = False
    fetched: bool = False
    fetch_error: str = ""
    fetch_ts: Optional[float] = None
    fetch_age_s: Optional[float] = None
    lanes: list = field(default_factory=list)
    kind: str = "measured"

    def as_dict(self) -> dict:
        return {
            "name": self.name,
            "workdir": self.workdir,
            "lanes": self.lanes,
            "status": self.status,
            "kind": self.kind,
            "lag": self.lag,
            "ahead": self.ahead,
            "branch": self.branch,
            "target_ref": self.target_ref,
            "detached": self.detached,
            "fetched": self.fetched,
            "fetch_error": self.fetch_error,
            "fetch_ts": iso_utc(self.fetch_ts) if self.fetch_ts else None,
            "fetch_age_s": (
                round(self.fetch_age_s, 1) if self.fetch_age_s is not None else None
            ),
            "value": self.value,
        }


def _warn(probe: Probe, kind: str, value: str) -> Probe:
    probe.status = UNMEASURABLE
    probe.kind = kind
    probe.value = value
    return probe


def resolve_ref(probe: Probe, root: str, timeout: int) -> Optional[str]:
    """Resolve the ref this workdir should be compared against.

    Order: the branch's upstream, then <remote>/<branch>, then <remote>/HEAD for
    a detached HEAD. Returns None after setting a WARN on the probe.
    """
    remotes = [n for n in git(root, "remote", timeout=timeout).out.split() if n]

    if not remotes:
        _warn(
            probe,
            "no-remote",
            f"no git remote configured ({root} tracks nothing); lag is unknowable",
        )
        return None

    preferred = "origin" if "origin" in remotes else remotes[0]
    if probe.detached:
        head = git(
            root, "rev-parse", "--abbrev-ref", f"{preferred}/HEAD", timeout=timeout
        )
        if head.ok:
            return head.out.strip()
        for candidate in (
            f"{preferred}/main",
            f"{preferred}/master",
            f"{preferred}/trunk",
        ):
            if git(
                root,
                "rev-parse",
                "--verify",
                "--quiet",
                f"refs/remotes/{candidate}",
                timeout=timeout,
            ).ok:
                return candidate
        _warn(
            probe,
            "detached-no-default",
            f"detached HEAD at {probe.branch or 'unknown'} and no {preferred}/HEAD to compare "
            f"against (remotes: {', '.join(remotes)})",
        )
        return None

    upstream = git(
        root,
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{u}",
        timeout=timeout,
    )
    if upstream.ok:
        return upstream.out.strip()

    # No upstream: a lane branch (e.g. wt/<ticket>) is common and must still be
    # measured against a remote branch of the same name if one exists.
    remote_cfg = git(
        root, "config", "--get", f"branch.{probe.branch}.remote", timeout=timeout
    )
    remote = remote_cfg.out.strip() if remote_cfg.ok else ""
    if not remote or remote == ".":
        remote = preferred
    candidate = f"{remote}/{probe.branch}"
    if git(
        root,
        "rev-parse",
        "--verify",
        "--quiet",
        f"refs/remotes/{candidate}",
        timeout=timeout,
    ).ok:
        return candidate
    _warn(
        probe,
        "no-upstream",
        f"branch {probe.branch!r} has no upstream and no {candidate} exists "
        f"(remotes: {', '.join(remotes)})",
    )
    return None


def probe_workdir(name: str, workdir: str, opts: argparse.Namespace) -> Probe:
    """Measure one workdir. Never raises: every defect becomes a named row."""
    probe = Probe(name=name, workdir=workdir)
    timeout = opts.timeout

    if not workdir or not workdir.strip():
        return _warn(probe, "no-workdir", "project row has an empty workdir")

    path = os.path.expanduser(workdir.strip())
    if not os.path.exists(path):
        return _warn(probe, "missing", f"workdir does not exist: {path}")
    if not os.path.isdir(path):
        return _warn(probe, "not-dir", f"workdir is not a directory: {path}")

    # A bare repo has no work tree, so `--show-toplevel` fails on it. Ask the bare
    # question first, or every bare workdir would be mislabelled "not a git workdir".
    bare = git(path, "rev-parse", "--is-bare-repository", timeout=timeout)
    if bare.ok and bare.out.strip() == "true":
        return _warn(
            probe,
            "bare",
            f"bare repository at {path}: a lane cannot dispatch from a tree with no worktree",
        )

    top = git(path, "rev-parse", "--show-toplevel", timeout=timeout)
    if not top.ok:
        return _warn(
            probe,
            "not-git",
            f"not a git workdir ({path}): {top.first_err()}",
        )
    root = top.out.strip()
    head = git(path, "rev-parse", "--verify", "HEAD", timeout=timeout)
    if not head.ok:
        return _warn(
            probe,
            "unborn",
            f"repository has no commits yet at {root}: {head.first_err()}",
        )
    head_sha = head.out.strip()[:12]

    branch_ref = git(path, "symbolic-ref", "-q", "--short", "HEAD", timeout=timeout)
    if branch_ref.ok and branch_ref.out.strip():
        probe.branch = branch_ref.out.strip()
    else:
        probe.detached = True
        probe.branch = f"(detached {head_sha})"

    target = resolve_ref(probe, path, timeout)
    if target is None:
        return probe  # resolve_ref already set the WARN and the measured value
    probe.target_ref = target

    # Fetch the remote that backs the comparison ref. A failed fetch does not
    # stop the measurement: the local refs still bound the lag from below.
    remote = target.split("/")[0]
    if opts.fetch:
        res = git(path, "fetch", "--quiet", "--no-tags", remote, timeout=timeout)
        probe.fetched = res.ok
        if not res.ok:
            probe.fetch_error = res.first_err()

    git_dir = git(path, "rev-parse", "--absolute-git-dir", timeout=timeout)
    if git_dir.ok:
        fetch_head = os.path.join(git_dir.out.strip(), "FETCH_HEAD")
        try:
            probe.fetch_ts = os.stat(fetch_head).st_mtime
            probe.fetch_age_s = max(0.0, time.time() - probe.fetch_ts)
        except OSError:
            probe.fetch_ts = None
            probe.fetch_age_s = None

    counts = git(
        path, "rev-list", "--left-right", "--count", f"HEAD...{target}", timeout=timeout
    )
    if not counts.ok:
        _warn(
            probe,
            "no-comparison",
            f"cannot count commits between HEAD and {target}: {counts.first_err()}",
        )
        return probe
    fields = counts.out.split()
    if len(fields) != 2:
        _warn(
            probe,
            "no-comparison",
            f"unexpected rev-list output {counts.out.strip()!r} for HEAD...{target}",
        )
        return probe
    probe.ahead, probe.lag = int(fields[0]), int(fields[1])

    if probe.fetch_age_s is None:
        fetch_text = "last fetch never (no FETCH_HEAD)"
    else:
        fetch_text = (
            f"last fetch {human_age(probe.fetch_age_s)} ago ({iso_utc(probe.fetch_ts)})"
        )
    measured = f"lag {probe.lag}, ahead {probe.ahead}, {probe.branch} vs {probe.target_ref}, {fetch_text}"

    stale = probe.lag > opts.bound
    if stale:
        probe.status = "FAIL"
        probe.value = (
            f"lag {probe.lag} > bound {opts.bound} ({probe.branch} vs {probe.target_ref}), "
            f"ahead {probe.ahead}, {fetch_text}"
        )
        if probe.fetch_error:
            probe.value += f"; fetch failed: {probe.fetch_error}"
        return probe

    if probe.fetch_error:
        probe.status = UNMEASURABLE
        probe.kind = "fetch-failed"
        probe.value = f"{measured}; fetch failed: {probe.fetch_error}"
        return probe
    if probe.detached:
        probe.status = UNMEASURABLE
        probe.kind = "detached"
        probe.value = f"{measured}; detached HEAD cannot be pushed or fast-forwarded"
        return probe

    probe.status = "PASS"
    probe.value = measured
    return probe


def load_projects(db_path: str, include_disabled: bool) -> list:
    """Read (name, workdir) from the scheduler's projects table, read-only."""
    path = os.path.expanduser(db_path)
    if not os.path.exists(path):
        raise ConfigError(f"scheduler database not found: {path}")
    if not os.path.isfile(path):
        raise ConfigError(f"scheduler database is not a file: {path}")
    try:
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=15)
    except sqlite3.Error as exc:
        raise ConfigError(f"cannot open {path} read-only: {exc}") from exc
    try:
        cols = {row[1] for row in con.execute("pragma table_info(projects)")}
        if not cols:
            raise ConfigError(f"{path} has no `projects` table")
        for needed in ("name", "workdir"):
            if needed not in cols:
                raise ConfigError(f"{path} `projects` table has no `{needed}` column")
        where = "" if include_disabled else " where enabled = 1"
        query = f"select name, workdir from projects{where} order by name"
        return [(row[0] or "", row[1] or "") for row in con.execute(query)]
    except sqlite3.Error as exc:
        raise ConfigError(f"cannot read projects from {path}: {exc}") from exc
    finally:
        con.close()


def unique_workdirs(projects: list) -> list:
    """Collapse lanes that share a workdir; keep every lane name for the row."""
    order: list = []
    lanes: dict = {}
    for name, workdir in projects:
        key = (
            os.path.realpath(os.path.expanduser(workdir.strip()))
            if workdir.strip()
            else ""
        )
        if key not in lanes:
            lanes[key] = []
            order.append(key)
        lanes[key].append(name or "(unnamed)")
    out = []
    for key in order:
        names = sorted(lanes[key])
        out.append((names[0], key if key else "", names))
    return out


def probe_all(targets: list, opts: argparse.Namespace) -> list:
    """Probe every target, in parallel, preserving sorted name order in output."""

    def one(item):
        name, workdir, lanes = item
        probe = probe_workdir(name, workdir, opts)
        probe.lanes = lanes
        if len(lanes) > 1:
            probe.value += f" [{len(lanes)} lanes: {', '.join(lanes)}]"
        return probe

    jobs = max(1, min(opts.jobs, len(targets) or 1))
    if jobs == 1:
        results = [one(item) for item in targets]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            results = list(pool.map(one, targets))
    return sorted(results, key=lambda p: (p.name, p.workdir))


def apply_bounds(results: list, opts: argparse.Namespace) -> None:
    """Second-pass bounds that can only tighten a row: fetch age, then --strict.

    A lag counted from refs nobody refreshed says nothing about the remote today,
    so --max-fetch-age fails the row even when the local count is zero. --strict
    runs last: an unmeasurable workdir cannot be cleared for dispatch either.
    """
    if opts.max_fetch_age is not None:
        for probe in results:
            if probe.status == "FAIL" or probe.fetch_age_s is None:
                continue
            age = int(probe.fetch_age_s)
            if age <= opts.max_fetch_age:
                continue
            probe.status = "FAIL"
            probe.kind = "fetch-age"
            probe.value = (
                f"last fetch {age}s > max {opts.max_fetch_age}s "
                f"({iso_utc(probe.fetch_ts)}), lag {probe.lag}"
            )
    if opts.strict:
        for probe in results:
            if probe.status == "WARN":
                probe.status = "FAIL"
                probe.kind = f"strict-{probe.kind}"
                probe.value = f"strict: {probe.value}"


def report_text(results: list, opts: argparse.Namespace, header: str) -> int:
    print(header)
    for probe in results:
        print(f"  {probe.status}  {probe.name} — {probe.value}")

    measured = [p for p in results if p.lag is not None]
    failed = [p for p in results if p.status == "FAIL"]
    warned = [p for p in results if p.status == "WARN"]
    passed = [p for p in results if p.status == "PASS"]
    fetch_failed = [p for p in results if p.fetch_error]
    max_lag = max((p.lag for p in measured), default=0)
    mode = "gate" if opts.gate else "report"
    plural = "workdir" if len(results) == 1 else "workdirs"
    print(
        f"repo-freshness: {len(results)} {plural}, {len(measured)} measured "
        f"({len(passed)} fresh, {len(failed)} failed), {len(warned)} unmeasurable, "
        f"{len(fetch_failed)} fetch errors "
        f"(bound {opts.bound}, fetch {'on' if opts.fetch else 'off'}, max lag {max_lag}, {mode})"
    )

    if failed:
        print(
            f"FRESHNESS: FAIL ({len(failed)} of {len(results)} workdirs, max lag {max_lag})"
        )
    else:
        print(f"FRESHNESS: PASS ({len(measured)} measured, max lag {max_lag})")
    if opts.gate and failed:
        return EXIT_GATE
    return EXIT_OK


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(
        description="measure how far each lane workdir is behind its remote"
    )
    ap.add_argument(
        "--db",
        default=os.environ.get(DB_ENV, DEFAULT_DB),
        help=f"scheduler sqlite database (default: ${DB_ENV} or {DEFAULT_DB})",
    )
    ap.add_argument(
        "--workdir",
        action="append",
        default=None,
        metavar="PATH",
        help="probe this workdir instead of the database (repeatable)",
    )
    ap.add_argument(
        "--include-disabled",
        action="store_true",
        help="also probe projects with enabled = 0",
    )
    ap.add_argument(
        "--bound",
        type=int,
        default=0,
        help="commits behind before a workdir is FAIL (default: 0)",
    )
    ap.add_argument(
        "--gate",
        action="store_true",
        help="exit 1 when any workdir FAILs, so a dispatcher can refuse",
    )
    ap.add_argument(
        "--strict",
        action="store_true",
        help="escalate every WARN (unmeasurable) to FAIL",
    )
    ap.add_argument(
        "--no-fetch",
        dest="fetch",
        action="store_false",
        help="measure what the local refs already know; no network call",
    )
    ap.add_argument(
        "--max-fetch-age",
        type=int,
        default=None,
        metavar="SECONDS",
        help="also FAIL when the last fetch is older than this (off by default)",
    )
    ap.add_argument(
        "--jobs", type=int, default=8, help="workdirs probed in parallel (default 8)"
    )
    ap.add_argument(
        "--timeout", type=int, default=60, help="per-git-command timeout (default 60s)"
    )
    ap.add_argument("--json", action="store_true", help="emit the measurements as JSON")
    opts = ap.parse_args(argv)

    try:
        if opts.bound < 0:
            raise ConfigError(f"--bound must be >= 0, got {opts.bound}")
        if opts.jobs < 1:
            raise ConfigError(f"--jobs must be >= 1, got {opts.jobs}")
        if opts.timeout < 1:
            raise ConfigError(f"--timeout must be >= 1, got {opts.timeout}")
        if opts.max_fetch_age is not None and opts.max_fetch_age < 0:
            raise ConfigError(f"--max-fetch-age must be >= 0, got {opts.max_fetch_age}")

        if opts.workdir:
            targets = []
            for raw in opts.workdir:
                path = os.path.expanduser(raw.strip())
                name = os.path.basename(os.path.normpath(path)) or path
                targets.append((name, path, [name]))
            header = (
                f"repo-freshness — {len(targets)} explicit workdir"
                f"{'' if len(targets) == 1 else 's'}, bound {opts.bound}, "
                f"fetch {'on' if opts.fetch else 'off'}"
            )
        else:
            db_path = os.path.expanduser(opts.db)
            projects = load_projects(opts.db, opts.include_disabled)
            if not projects:
                raise ConfigError(
                    f"{db_path} has no "
                    f"{'projects' if opts.include_disabled else 'enabled projects'}"
                )
            targets = unique_workdirs(projects)
            header = (
                f"repo-freshness — db {db_path}, {len(projects)} "
                f"{'projects' if opts.include_disabled else 'enabled projects'}, "
                f"{len(targets)} unique workdirs, bound {opts.bound}, "
                f"fetch {'on' if opts.fetch else 'off'}"
            )
    except ConfigError as exc:
        print(f"  FAIL  scheduler-db — {exc}")
        print(f"FRESHNESS: FAIL (config: {exc})")
        return EXIT_CONFIG

    results = probe_all(targets, opts)
    apply_bounds(results, opts)

    if opts.json:
        payload = {
            "header": header,
            "bound": opts.bound,
            "fetch": opts.fetch,
            "strict": opts.strict,
            "gate": opts.gate,
            "max_fetch_age": opts.max_fetch_age,
            "workdirs": [p.as_dict() for p in results],
            "failed": sum(1 for p in results if p.status == "FAIL"),
            "warned": sum(1 for p in results if p.status == "WARN"),
            "passed": sum(1 for p in results if p.status == "PASS"),
        }
        print(json.dumps(payload, indent=2))
        if opts.gate and payload["failed"]:
            return EXIT_GATE
        return EXIT_OK

    return report_text(results, opts, header)


if __name__ == "__main__":
    sys.exit(main())
