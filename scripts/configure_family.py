#!/usr/bin/env python3
"""configure_family.py — extend the code-factory lane family to the canonical shape.

The shape is DERIVED from the two existing families in the live DB (crier, 9router),
never hand-enumerated: every satellite a family carries there, code-factory must carry too.
Idempotent: an existing lane is configured, not duplicated.

Write contract (CF-356) — the run that configured 1 of 16 lanes in 170 s:

  * ONE WRITE TRANSACTION PER LANE.  Every daemon call for a lane happens BEFORE
    that lane's write, and `configure_lane()` commits the lane's own UPDATE before
    the next lane starts.  No write lock is therefore held while this script waits
    on the daemon, and the daemon never waits on this script (the pre-fix shape
    held one transaction across the whole loop, so the daemon's INSERT for the
    next lane answered `500 database is locked (SQLITE_BUSY)`).
  * A locked/busy write (`database is locked` / `database is busy`) is retried up
    to BUSY_ATTEMPTS attempts with a monotonically increasing backoff, and the
    per-lane outcome is recorded: `configured`, `already` (the row already carried
    the intended values) or `failed` with the reason it was refused.
  * Exit status: EXIT_OK (0) ONLY when every targeted lane reached its intended
    state.  A shortfall prints each unconfigured lane with its recorded reason and
    exits EXIT_SHORTFALL (2).  A token/DB/shape failure exits EXIT_PRECONDITION
    (3) instead of printing a summary and returning 0.

Testability seams (all optional; the CLI behaviour is unchanged — no flags):

  SCHEDULER_OPERATOR_TOKEN   operator token (default: /proc/<PID>/environ, see F2-2)
  SCHEDULER_DB               scheduler sqlite path (default ~/.hermes/.../scheduler.db)
  SCHEDULER_API              scheduler API base (default http://127.0.0.1:9090)

F2-2 stays OPEN: the token still defaults to the hardcoded PID's /proc/<PID>/environ.
The environment override is a seam for tests and operators; it does not fix F2-2.
"""

import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lane_target  # noqa: E402  (same directory, keeps the target model in one place)
import cooldown_policy  # noqa: E402

DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")
API = "http://127.0.0.1:9090"
ROOT = os.path.expanduser("~/code-factory")

PID = "1755676"

EXIT_OK = 0
EXIT_SHORTFALL = 2
EXIT_PRECONDITION = 3

# Bounded busy retry: BUSY_ATTEMPTS attempts in total, backing off
# 0.25 s -> 0.5 s -> 1 s -> 2 s (monotonically increasing, ~3.75 s worst case).
BUSY_ATTEMPTS = 5
BUSY_BACKOFF_START_S = 0.25
BUSY_BACKOFF_FACTOR = 2.0

# Per-attempt sqlite wait. Bounded on purpose: a contended write surfaces as a
# retryable busy error instead of the pre-fix 60 s stall that deadlocked the loop.
BUSY_TIMEOUT_MS = 5000

# The columns this script owns on a lane row, in the order it reads and writes them.
INTENDED = (
    "parent",
    "admission_mode",
    "prompt",
    "prompt_mode",
    "cooldown_floor_s",
    "cooldown_ceiling_s",
)

# --- prompts for the lanes that need a new one --------------------------------------
PROMPTS = {
    "docs": """Your job: keep the documentation true to the code.

1. Pick the largest documentation claim the last week's commits made false.
2. Correct it in the doc, quoting the code path that proves the new statement.
3. Never document an intention as if it were behaviour. If it is not measured, say "not measured".
4. Report: claims corrected, claims you could not verify, the file and line for each.
""",
    "readme": """Your job: the README is the first thing a stranger reads.

1. Follow every command in `README.md` literally and record where it fails.
2. Keep the status table honest: a piece that is "works" must have a command behind it, and a
   piece that is "not yet" must say what is missing.
3. Remove anything that only makes sense to an insider.
4. Report: commands tested, commands that failed, wording that promised more than the code does.
""",
    "releng": """Your job: releases and the state of the tree.

1. Verify the tree builds and `tests/selftest.sh` is green from a clean checkout.
2. Check the repo's public posture: no secrets, no internal endpoints, license present,
   branch protection and secret scanning on.
3. If a release is due, tag it from a green commit and write the notes from board rows, not
   from memory.
4. Report: build status, gate status, public-posture findings, what was tagged.
""",
    "perf": """Your job: measure, do not estimate.

1. Time the paths this repo owns: `tests/selftest.sh`, a node provision, a repo clone, a build.
2. Compare against the last recorded numbers; a regression is a finding, not noise.
3. Propose one change at a time, with the measurement that justifies it.
4. Report: metric, before, after, and the command that produced both.
""",
}

# --- per-lane prompt mapping -------------------------------------------------------
LANE_PROMPT = {
    "qa": "qa",
    "docs": "docs",
    "readme": "readme",
    "releng": "releng",
    "perf": "perf",
    "pm": "pm",
    "dogfood": "dogfood",
    "sync": "sync",
    "duckbrain": "duckbrain",
}


class PreconditionError(RuntimeError):
    """Token, DB or family-shape unavailable: no lane can be targeted at all."""


@dataclass
class LaneOutcome:
    """What happened to one lane. `kind` is configured / already / failed."""

    kind: str
    name: str
    reason: str = ""
    attempts: int = 1
    created: bool = False
    detail: str = ""


def resolve_token():
    """Operator token: env override first, then the /proc read (F2-2 default)."""
    override = os.environ.get("SCHEDULER_OPERATOR_TOKEN", "").strip()
    if override:
        return override
    try:
        raw = open(f"/proc/{PID}/environ", "rb").read().decode(errors="replace")
    except OSError as exc:
        raise PreconditionError(
            f"scheduler operator token unavailable: cannot read /proc/{PID}/environ "
            f"({exc}); set SCHEDULER_OPERATOR_TOKEN"
        ) from exc
    for entry in raw.split("\0"):
        if entry.startswith("SCHEDULER_OPERATOR_TOKEN="):
            token = entry.split("=", 1)[1].strip()
            if token:
                return token
    raise PreconditionError(
        f"scheduler operator token unavailable: SCHEDULER_OPERATOR_TOKEN is not in "
        f"/proc/{PID}/environ; set SCHEDULER_OPERATOR_TOKEN"
    )


def api(method, path, body=None, *, token, api_base=API, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        api_base.rstrip("/") + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode() or "{}")
    except urllib.error.HTTPError as exc:
        return exc.code, {"error": exc.read().decode()[:200]}
    except OSError as exc:  # URLError, connection refused, timeout
        return 599, {"error": f"{type(exc).__name__}: {exc}"[:200]}


def busy_backoff(attempt):
    """Delay before retry `attempt` (1-based): monotonically increasing, bounded."""
    return BUSY_BACKOFF_START_S * (BUSY_BACKOFF_FACTOR ** (attempt - 1))


def is_busy(exc):
    text = str(exc).lower()
    return "database is locked" in text or "database is busy" in text


def rollback(con):
    try:
        con.rollback()
    except sqlite3.Error:
        pass


def configure_lane(
    con,
    name,
    desired,
    *,
    attempts=BUSY_ATTEMPTS,
    sleep=time.sleep,
    backoff=busy_backoff,
):
    """Configure ONE lane in its OWN transaction; retry a busy write with backoff.

    The commit at the end of this function is the whole transaction boundary: a
    single lane is written and released before the caller moves on, so nothing
    outside this process waits on the write lock while an API call is in flight.
    """
    wanted = {column: desired[column] for column in INTENDED}
    last_error = ""
    for attempt in range(1, attempts + 1):
        try:
            row = con.execute(
                "SELECT " + ", ".join(INTENDED) + " FROM projects WHERE name = ?",
                (name,),
            ).fetchone()
            if row is None:
                return LaneOutcome(
                    "failed", name, "no project row to configure", attempt
                )
            if all(
                row[index] == wanted[column] for index, column in enumerate(INTENDED)
            ):
                return LaneOutcome("already", name, "", attempt)
            cursor = con.execute(
                "UPDATE projects SET parent=?, admission_mode=?, prompt=?, "
                "prompt_mode=?, cooldown_floor_s=?, cooldown_ceiling_s=? WHERE name=?",
                tuple(wanted[column] for column in INTENDED) + (name,),
            )
            if cursor.rowcount != 1:
                rollback(con)
                return LaneOutcome(
                    "failed",
                    name,
                    f"UPDATE matched {cursor.rowcount} rows",
                    attempt,
                )
            con.commit()
            return LaneOutcome("configured", name, "", attempt)
        except sqlite3.OperationalError as exc:
            rollback(con)
            last_error = str(exc)
            if not is_busy(exc):
                return LaneOutcome("failed", name, f"write refused: {exc}", attempt)
            if attempt < attempts:
                sleep(backoff(attempt))
        except sqlite3.Error as exc:
            rollback(con)
            return LaneOutcome("failed", name, f"write failed: {exc}", attempt)
    return LaneOutcome(
        "failed",
        name,
        f"write refused after {attempts} attempts, database stayed locked: {last_error}",
        attempts,
    )


def derive_shape(con, families=("crier", "9router")):
    """The canonical satellite suffixes, derived from the two existing families."""
    shape = {}
    for family in families:
        for name, namespace, mode, floor, workdir in con.execute(
            "SELECT name, namespace_id, admission_mode, COALESCE(cooldown_floor_s,0), "
            "workdir FROM projects WHERE name LIKE ? AND name != ? ORDER BY name",
            (f"{family}%", family),
        ):
            suffix = name[len(family) :].lstrip("-")  # e.g. "docs-qa"
            if suffix and suffix not in shape:
                shape[suffix] = (
                    namespace,
                    mode,
                    floor,
                    (workdir or "").replace(family, "<p>"),
                )
    return shape


def write_prompts(root):
    """Materialise the lane prompts this repo owns, under <root>/prompts."""
    prompts_dir = os.path.join(root, "prompts")
    os.makedirs(prompts_dir, exist_ok=True)
    written = []
    for lane, text in PROMPTS.items():
        path = os.path.join(prompts_dir, f"{lane}.md")
        with open(path, "w") as f:
            f.write(
                f"# Lane prompt — code-factory / {lane}\n\nYou are the {lane} lane for the "
                f"`code-factory` project: the repo that builds the distributed coding workforce.\n\n"
                + text
                + "\n## Ground rules\n\n- `AGENTS.md` is the working agreement; specs are the design "
                "authority.\n- The board is `.coding-hermes/board/tasks.jsonl` — append only.\n"
                "- Never claim a row complete without a command someone else can re-run.\n"
                "- No secrets, no internal endpoints, no personal data: this repo is public.\n"
            )
        written.append(path)
        print("wrote", path)
    return written


def lane_desired(root, name, suffix, mode):
    """The intended row values for one lane (raises CooldownPolicyError)."""
    base = suffix.split("-")[0]
    prompt_file = os.path.join(
        root, "prompts", f"{LANE_PROMPT.get(base, 'foreman')}.md"
    )
    prompt = ""
    if os.path.exists(prompt_file):
        with open(prompt_file) as handle:
            prompt = handle.read()
    policy = cooldown_policy.policy_for_lane(name)
    return {
        "parent": "code-factory",
        "admission_mode": mode or "cooldown",
        "prompt": prompt,
        "prompt_mode": "append",
        "cooldown_floor_s": policy["floor_s"],
        "cooldown_ceiling_s": policy["ceiling_s"],
    }


def configure_one_lane(con, api_fn, root, suffix, namespace, mode, workdir_template):
    """Create (if absent), set the namespace via the API, then write the local row.

    Order is load-bearing (CF-356): every daemon call happens BEFORE this lane's
    write, and `configure_lane()` commits that write before the next lane starts.
    A daemon waiting on this script's lock can therefore never deadlock against
    this script waiting on the daemon.
    """
    name = f"code-factory-{suffix}"
    workdir = workdir_template.replace("<p>", "code-factory")
    # A workdir is a TARGET, not necessarily a local directory: it may be
    # user@host:/path, ssh://user@host:port/path, sftp://..., ftp://..., or
    # bunker://<agent>/path. Only a local target gets mkdir'd; a remote target is
    # registered as-is and left for the node side to materialise (CF-046).
    try:
        target = lane_target.parse(workdir)
    except lane_target.TargetError as exc:
        return LaneOutcome("failed", name, f"invalid workdir target {workdir!r}: {exc}")
    remote_note = ""
    if target.is_local:
        os.makedirs(target.path, exist_ok=True)
        workdir = target.path
    else:
        remote_note = f" remote={target.display()} (no local mkdir)"
        print(f"note: {name} workdir is remote: {target.display()}")

    status, data = api_fn(
        "POST",
        "/api/v1/projects",
        {"name": name, "repo_url": f"local:{root}", "workdir": workdir},
    )
    created = status == 201
    if status not in (201, 409):
        reason = f"{data.get('error', '')}".strip() if isinstance(data, dict) else ""
        return LaneOutcome("failed", name, f"create refused: {status} {reason}".strip())
    try:
        desired = lane_desired(root, name, suffix, mode)
    except cooldown_policy.CooldownPolicyError as exc:
        return LaneOutcome("failed", name, f"no lane policy: {exc}")
    # configure: namespace via the API (refreshes the daemon's view), the rest directly
    api_fn("PUT", f"/api/v1/projects/{name}", {"namespace_id": namespace})
    outcome = configure_lane(con, name, desired)
    outcome.created = created
    outcome.detail = (
        f" ns={namespace} mode={desired['admission_mode']} "
        f"floor={desired['cooldown_floor_s']}{remote_note}"
    )
    return outcome


def main(argv=None, *, api_fn=None, db_path=None, root=None, token=None):
    """Configure the family. Returns EXIT_OK / EXIT_SHORTFALL / EXIT_PRECONDITION.

    `argv` is accepted for symmetry with the other lane scripts; this script takes
    no flags, so it is ignored. The keyword seams exist for hermetic tests.
    """
    del argv
    db_path = db_path or os.environ.get("SCHEDULER_DB") or DB
    root = root or ROOT
    if token is None:
        try:
            token = resolve_token()
        except PreconditionError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return EXIT_PRECONDITION
    if api_fn is None:
        api_base = os.environ.get("SCHEDULER_API") or API

        def api_fn(method, path, body=None):
            return api(method, path, body, token=token, api_base=api_base)

    try:
        con = sqlite3.connect(db_path, timeout=BUSY_TIMEOUT_MS / 1000)
    except sqlite3.Error as exc:
        print(f"ERROR: cannot open the scheduler DB {db_path}: {exc}", file=sys.stderr)
        return EXIT_PRECONDITION
    con.execute(f"PRAGMA busy_timeout={BUSY_TIMEOUT_MS}")
    try:
        try:
            shape = derive_shape(con)
        except sqlite3.Error as exc:
            print(
                f"ERROR: cannot derive the family shape from {db_path}: {exc}",
                file=sys.stderr,
            )
            return EXIT_PRECONDITION
        if not shape:
            print(
                "ERROR: derived no satellite suffixes from crier/9router; refusing to "
                f"report success against {db_path}",
                file=sys.stderr,
            )
            return EXIT_PRECONDITION
        print(
            "derived shape from crier, 9router ->", ", ".join(sorted(shape)) or "none"
        )
        write_prompts(root)

        outcomes = [
            configure_one_lane(con, api_fn, root, suffix, namespace, mode, workdir)
            for suffix, (namespace, mode, _floor, workdir) in sorted(shape.items())
        ]
        configured = [o for o in outcomes if o.kind == "configured"]
        already = [o for o in outcomes if o.kind == "already"]
        refused = [o for o in outcomes if o.kind == "failed"]

        for outcome in outcomes:
            print(f"  {outcome.kind:10s} {outcome.name}{outcome.detail}")
        print(
            f"\nsummary targeted={len(outcomes)} configured={len(configured)} "
            f"already={len(already)} refused={len(refused)}"
        )
        for outcome in refused:
            # Named per lane, with the reason it was recorded: the run is not a success.
            print(f"refused: {outcome.name}: {outcome.reason}", file=sys.stderr)
        print("\nfamily now:")
        for row in con.execute(
            "SELECT name, namespace_id, admission_mode, cooldown_floor_s FROM projects "
            "WHERE name LIKE 'code-factory%' ORDER BY name"
        ):
            print(
                f"  {row[0]:30s} ns={str(row[1]):14s} mode={str(row[2]):9s} floor={row[3]}"
            )
        return EXIT_OK if not refused else EXIT_SHORTFALL
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
