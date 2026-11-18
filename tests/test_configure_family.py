"""CF-356 — the `configure_family.py` write contract, proved hermetically.

The measured defect this suite pins: the script opened ONE sqlite connection,
issued a per-lane `UPDATE ...` inside the loop, and committed only after the loop,
so its write transaction was held for the whole run. The scheduler daemon's own
INSERT for the next lane answered `500 database is locked (SQLITE_BUSY)`, one of
sixteen lanes was configured, and the script still exited 0.

Arms, each able to fail:

  A. per-lane transaction — every lane's UPDATE is committed before the next lane's
     API call, so a second connection taking its own write (the daemon's INSERT)
     with `busy_timeout=0` never meets this script's lock.
  B. busy retry — a held `BEGIN IMMEDIATE` makes the lane write raise
     `database is locked`; injected sleeps record the backoff, the retry recovers
     once the lock is released, and an exhausted retry is recorded for that lane.
  C. exit status — an unconfigured lane is named, and both `main()` and a real
     process exit non-zero (2) instead of printing a summary and returning 0.
  D. red control — the PRE-FIX body materialised with `git show` out of the
     revision before this fix, driven through the same refusal, exits 0 with zero
     lanes configured.

No network, no live daemon, no /proc: temp dirs and a loopback stub only.
"""

import io
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stderr, redirect_stdout
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
SCRIPTS = REPO / "scripts"
sys.path.insert(0, str(SCRIPTS))

import configure_family  # noqa: E402  (importable only because resolution is lazy)
import cooldown_policy  # noqa: E402

PROJECTS_DDL = """
CREATE TABLE projects (
    name TEXT PRIMARY KEY,
    namespace_id TEXT,
    admission_mode TEXT,
    cooldown_floor_s INTEGER,
    cooldown_ceiling_s INTEGER,
    workdir TEXT,
    parent TEXT,
    prompt TEXT,
    prompt_mode TEXT
)
"""

# The satellite suffixes the two live families carry; the shape is derived from them.
SUFFIXES = (
    "docs",
    "qa",
    "pm",
    "sync",
    "dogfood",
    "releng",
    "readme",
    "perf",
    "review",
    "duckbrain",
)
FAMILIES = ("crier", "9router")


def make_db(path, workdir_root):
    """A scheduler DB with the shape the script reads, seeded from two families."""
    con = sqlite3.connect(str(path))
    try:
        con.executescript(PROJECTS_DDL)
        for family in FAMILIES:
            con.execute(
                "INSERT INTO projects (name, namespace_id, admission_mode, "
                "cooldown_floor_s, workdir) VALUES (?, ?, ?, ?, ?)",
                (family, family, "tasks", 0, os.path.join(str(workdir_root), family)),
            )
            for suffix in SUFFIXES:
                con.execute(
                    "INSERT INTO projects (name, namespace_id, admission_mode, "
                    "cooldown_floor_s, workdir) VALUES (?, ?, ?, ?, ?)",
                    (
                        f"{family}-{suffix}",
                        suffix,
                        "cooldown",
                        0,
                        os.path.join(str(workdir_root), f"{family}-{suffix}"),
                    ),
                )
        con.commit()
    finally:
        con.close()
    return path


def desired_for(name, prompt="lane prompt"):
    """The intended row values for a lane, from the same policy the script uses."""
    policy = cooldown_policy.policy_for_lane(name)
    return {
        "parent": "code-factory",
        "admission_mode": "cooldown",
        "prompt": prompt,
        "prompt_mode": "append",
        "cooldown_floor_s": policy["floor_s"],
        "cooldown_ceiling_s": policy["ceiling_s"],
    }


def connect(path, busy_timeout_ms=0):
    con = sqlite3.connect(str(path), timeout=0)
    con.execute(f"PRAGMA busy_timeout={int(busy_timeout_ms)}")
    return con


class FakeApi:
    """The scheduler's project endpoints, without a daemon.

    Every write it makes uses its OWN connection with `busy_timeout=0`, i.e. it
    refuses to wait: if the script were holding a write transaction across the
    loop, this stand-in would raise `database is locked` exactly like the daemon
    answered `500`. What it sees is also recorded, so "each lane was committed
    before the next API call" is an observation, not a claim.
    """

    def __init__(self, db_path, refuse=None):
        self.db_path = str(db_path)
        self.refuse = dict(refuse or {})
        self.refuse_all = self.refuse.pop("*", None)
        self.calls = []
        self.created = []
        self.insert_failures = []
        self.committed_before_post = []

    def __call__(self, method, path, body=None):
        self.calls.append((method, path, body))
        if method == "POST":
            name = body["name"]
            self.committed_before_post.append(self._committed_lanes())
            if self.refuse_all is not None or name in self.refuse:
                return self.refuse_all or self.refuse[name], {"error": "stub refusal"}
            self._insert(name, body)
            self.created.append(name)
            return 201, {"project": {"name": name}}
        if method == "PUT":
            name = path.rsplit("/", 1)[-1]
            if self.refuse_all is not None or name in self.refuse:
                return self.refuse_all or self.refuse[name], {"error": "stub refusal"}
            self._update(name, body or {})
            return 200, {"project": {"name": name}}
        return 405, {}

    def _committed_lanes(self):
        con = connect(self.db_path)
        try:
            return con.execute(
                "SELECT COUNT(*) FROM projects WHERE name LIKE 'code-factory-%' "
                "AND parent = 'code-factory'"
            ).fetchone()[0]
        finally:
            con.close()

    def _insert(self, name, body):
        con = connect(self.db_path)
        try:
            con.execute(
                "INSERT INTO projects (name, namespace_id, admission_mode, "
                "cooldown_floor_s, workdir) VALUES (?, ?, ?, ?, ?)",
                (name, None, None, None, body.get("workdir")),
            )
            con.commit()
        except sqlite3.OperationalError as exc:
            self.insert_failures.append((name, str(exc)))
            raise
        finally:
            con.close()

    def _update(self, name, body):
        con = connect(self.db_path)
        try:
            if "namespace_id" in body:
                con.execute(
                    "UPDATE projects SET namespace_id = ? WHERE name = ?",
                    (body["namespace_id"], name),
                )
                con.commit()
        finally:
            con.close()


class PrefixSource:
    """The pre-fix script body, byte-identical from the revision before this fix."""

    ENV_REV = "CF356_PREFIX_REV"
    # `board: close CF-495 ...` — the commit this fix sits on top of.
    PINNED_REV = "214a749d"
    DRIVER = """\
import builtins
import io
import sys
import urllib.error
import urllib.request

real_open = builtins.open


def patched_open(file, *args, **kwargs):
    if isinstance(file, str) and file.startswith("/proc/") and file.endswith("/environ"):
        return io.BytesIO(b"SCHEDULER_OPERATOR_TOKEN=stub-token\\x00")
    return real_open(file, *args, **kwargs)


builtins.open = patched_open


def refuse(request, timeout=None):
    raise urllib.error.HTTPError(
        request.full_url, 500, "stub refusal", None, io.BytesIO(b"stub refusal")
    )


urllib.request.urlopen = refuse

source_path = sys.argv[1]
sys.path.insert(0, sys.argv[2])
import lane_target  # noqa: F401
import cooldown_policy  # noqa: F401

src = real_open(source_path).read()
namespace = {"__name__": "cf356_prefix", "__file__": source_path}
exec(compile(src, source_path, "exec"), namespace)
print("CONFIGURED=%d FAILED=%d" % (
    len(namespace.get("configured") or []), len(namespace.get("failed") or [])
))
"""

    @classmethod
    def candidate_revs(cls):
        """Revisions worth asking for, most specific first (deduped)."""
        revs = [os.environ.get(cls.ENV_REV), cls.PINNED_REV, "HEAD~1"]
        history = subprocess.run(
            [
                "git",
                "-C",
                str(REPO),
                "rev-list",
                "--max-count=8",
                "--all",
                "--",
                "scripts/configure_family.py",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if history.returncode == 0:
            revs.extend(history.stdout.split())
        seen = []
        for rev in revs:
            if rev and rev not in seen:
                seen.append(rev)
        return seen

    @classmethod
    def materialise(cls, target):
        """Write the pre-fix source to `target` and return the revision it came from."""
        tried = []
        for rev in cls.candidate_revs():
            tried.append(rev)
            proc = subprocess.run(
                ["git", "-C", str(REPO), "show", f"{rev}:scripts/configure_family.py"],
                capture_output=True,
                text=True,
                check=False,
            )
            if proc.returncode != 0:
                continue
            source = proc.stdout
            # Pre-fix shape: one commit after the loop, no bounded retry constants.
            if "con.commit()" in source and "BUSY_ATTEMPTS" not in source:
                Path(target).write_text(source)
                return rev
        raise AssertionError(
            "no pre-fix revision of scripts/configure_family.py found "
            f"(tried {tried}); set {cls.ENV_REV} to the commit before the CF-356 fix"
        )


class PerLaneTransactionTest(unittest.TestCase):
    """A: one write transaction per lane; the daemon never waits on our lock."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="cf356-tx-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.db = make_db(self.root / "scheduler.db", self.root / "lanes")

    def test_each_lane_is_committed_before_the_next_api_call(self):
        api = FakeApi(self.db)
        out = io.StringIO()
        with redirect_stdout(out):
            rc = configure_family.main(
                api_fn=api,
                db_path=str(self.db),
                root=str(self.root),
                token="stub-token",
            )
        self.assertEqual(rc, configure_family.EXIT_OK, out.getvalue())
        # The daemon stand-in never met this script's write lock ...
        self.assertEqual(api.insert_failures, [])
        # ... because lane N's API call already saw N-1 lanes committed.
        self.assertEqual(api.committed_before_post, list(range(len(SUFFIXES))))
        self.assertIn("refused=0", out.getvalue())

    def test_every_targeted_lane_reaches_its_intended_state(self):
        api = FakeApi(self.db)
        with redirect_stdout(io.StringIO()):
            rc = configure_family.main(
                api_fn=api,
                db_path=str(self.db),
                root=str(self.root),
                token="stub-token",
            )
        self.assertEqual(rc, configure_family.EXIT_OK)
        con = connect(self.db)
        try:
            rows = con.execute(
                "SELECT name, parent, prompt_mode, admission_mode, cooldown_floor_s, "
                "cooldown_ceiling_s FROM projects WHERE name LIKE 'code-factory-%' "
                "ORDER BY name"
            ).fetchall()
        finally:
            con.close()
        self.assertEqual(len(rows), len(SUFFIXES))
        for name, parent, prompt_mode, mode, floor, ceiling in rows:
            policy = cooldown_policy.policy_for_lane(name)
            self.assertEqual(parent, "code-factory", name)
            self.assertEqual(prompt_mode, "append", name)
            self.assertEqual(mode, "cooldown", name)
            self.assertEqual(floor, policy["floor_s"], name)
            self.assertEqual(ceiling, policy["ceiling_s"], name)


class BusyRetryTest(unittest.TestCase):
    """B: a locked write is retried with backoff, recorded per lane."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="cf356-busy-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.db = make_db(self.root / "scheduler.db", self.root / "lanes")
        con = connect(self.db)
        try:
            con.execute(
                "INSERT INTO projects (name, namespace_id, admission_mode, "
                "cooldown_floor_s, workdir) VALUES (?, ?, ?, ?, ?)",
                ("code-factory-docs", "docs", "cooldown", 0, str(self.root / "lanes")),
            )
            con.commit()
        finally:
            con.close()

    def _row(self, name):
        con = connect(self.db)
        try:
            return con.execute(
                "SELECT parent, admission_mode, cooldown_floor_s FROM projects "
                "WHERE name = ?",
                (name,),
            ).fetchone()
        finally:
            con.close()

    def test_backoff_is_monotonic(self):
        delays = [
            configure_family.busy_backoff(attempt)
            for attempt in range(1, configure_family.BUSY_ATTEMPTS)
        ]
        self.assertEqual(delays, sorted(delays))
        self.assertEqual(len(set(delays)), len(delays))
        self.assertTrue(all(delay > 0 for delay in delays), delays)

    def test_locked_write_recovers_on_retry_once_the_lock_is_released(self):
        con = connect(self.db)
        self.addCleanup(con.close)
        locker = connect(self.db)
        self.addCleanup(locker.close)
        locker.execute("BEGIN IMMEDIATE")  # the daemon's INSERT, in effect
        delays = []

        def sleep(seconds):
            delays.append(seconds)
            if len(delays) == 2:
                locker.commit()  # released only after two refused attempts

        outcome = configure_family.configure_lane(
            con, "code-factory-docs", desired_for("code-factory-docs"), sleep=sleep
        )
        self.assertEqual(outcome.kind, "configured", outcome.reason)
        self.assertEqual(outcome.attempts, 3)
        self.assertEqual(
            delays,
            [
                configure_family.busy_backoff(1),
                configure_family.busy_backoff(2),
            ],
        )
        self.assertEqual(
            self._row("code-factory-docs"),
            (
                "code-factory",
                "cooldown",
                cooldown_policy.policy_for_lane("code-factory-docs")["floor_s"],
            ),
        )

    def test_exhausted_retries_are_recorded_for_that_lane(self):
        con = connect(self.db)
        self.addCleanup(con.close)
        locker = connect(self.db)
        self.addCleanup(locker.close)
        locker.execute("BEGIN IMMEDIATE")
        delays = []

        outcome = configure_family.configure_lane(
            con,
            "code-factory-docs",
            desired_for("code-factory-docs"),
            sleep=delays.append,
        )
        self.assertEqual(outcome.kind, "failed")
        self.assertEqual(outcome.attempts, configure_family.BUSY_ATTEMPTS)
        self.assertIn("locked", outcome.reason.lower())
        self.assertIn(str(configure_family.BUSY_ATTEMPTS), outcome.reason)
        self.assertEqual(len(delays), configure_family.BUSY_ATTEMPTS - 1)
        self.assertEqual(delays, sorted(delays))
        # The lane was left untouched, not half-written.
        self.assertIsNone(self._row("code-factory-docs")[0])

    def test_non_busy_write_error_fails_without_retrying(self):
        empty = connect(self.root / "no-schema.db")
        self.addCleanup(empty.close)
        delays = []
        outcome = configure_family.configure_lane(
            empty,
            "code-factory-docs",
            desired_for("code-factory-docs"),
            sleep=delays.append,
        )
        self.assertEqual(outcome.kind, "failed")
        self.assertEqual(outcome.attempts, 1)
        self.assertEqual(delays, [])

    def test_a_lane_already_at_its_intended_state_is_reported_already(self):
        con = connect(self.db)
        self.addCleanup(con.close)
        wanted = desired_for("code-factory-docs")
        con.execute(
            "UPDATE projects SET parent=?, admission_mode=?, prompt=?, prompt_mode=?, "
            "cooldown_floor_s=?, cooldown_ceiling_s=? WHERE name=?",
            (
                wanted["parent"],
                wanted["admission_mode"],
                wanted["prompt"],
                wanted["prompt_mode"],
                wanted["cooldown_floor_s"],
                wanted["cooldown_ceiling_s"],
                "code-factory-docs",
            ),
        )
        con.commit()
        outcome = configure_family.configure_lane(con, "code-factory-docs", wanted)
        self.assertEqual(outcome.kind, "already")
        self.assertEqual(outcome.attempts, 1)


class ExitStatusTest(unittest.TestCase):
    """C: a shortfall is named and exits non-zero; success is reachable."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="cf356-exit-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.db = make_db(self.root / "scheduler.db", self.root / "lanes")

    def test_main_names_the_unconfigured_lane_and_returns_nonzero(self):
        api = FakeApi(self.db, refuse={"code-factory-perf": 500})
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = configure_family.main(
                api_fn=api,
                db_path=str(self.db),
                root=str(self.root),
                token="stub-token",
            )
        self.assertEqual(rc, configure_family.EXIT_SHORTFALL)
        self.assertNotEqual(rc, 0)
        self.assertIn("refused: code-factory-perf:", err.getvalue())
        self.assertIn("refused=1", out.getvalue())
        self.assertIn(f"targeted={len(SUFFIXES)}", out.getvalue())
        # The refusal is confined to the refused lane: the rest were configured.
        self.assertIn(f"configured={len(SUFFIXES) - 1}", out.getvalue())

    def test_an_unavailable_token_is_a_precondition_failure(self):
        err = io.StringIO()
        with (
            redirect_stderr(err),
            mock.patch.dict(os.environ, {"SCHEDULER_OPERATOR_TOKEN": ""}),
            mock.patch("builtins.open", side_effect=OSError("no /proc here")),
        ):
            rc = configure_family.main(
                api_fn=FakeApi(self.db),
                db_path=str(self.db),
                root=str(self.root),
                token=None,
            )
        self.assertEqual(rc, configure_family.EXIT_PRECONDITION)
        self.assertIn("scheduler operator token unavailable", err.getvalue())

    def test_an_unreadable_database_is_a_precondition_failure(self):
        api = FakeApi(self.db)
        broken = self.root / "not-a-db"
        broken.write_text("this is not sqlite\n")
        err = io.StringIO()
        with redirect_stderr(err), redirect_stdout(io.StringIO()):
            rc = configure_family.main(
                api_fn=api, db_path=str(broken), root=str(self.root), token="stub"
            )
        self.assertEqual(rc, configure_family.EXIT_PRECONDITION)
        self.assertEqual(api.calls, [])


class StubScheduler(BaseHTTPRequestHandler):
    """A scheduler stand-in over real HTTP, for the process-level exit-code arms."""

    state = None

    def log_message(self, *_args):
        pass

    def _read(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        return json.loads(raw) if raw else {}

    def _reply(self, status, body=None):
        raw = json.dumps(body or {}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _handle(self):
        body = self._read() if self.command in {"POST", "PUT"} else {}
        self.state["requests"].append((self.command, self.path, body))
        name = body.get("name") or self.path.rsplit("/", 1)[-1]
        if self.state["refuse_all"] or name in self.state["refuse"]:
            self._reply(self.state["refuse"].get(name, self.state["refuse_all"] or 500))
            return
        con = connect(self.state["db"])
        try:
            if self.command == "POST":
                con.execute(
                    "INSERT INTO projects (name, namespace_id, admission_mode, "
                    "cooldown_floor_s, workdir) VALUES (?, ?, ?, ?, ?)",
                    (name, None, None, None, body.get("workdir")),
                )
            elif self.command == "PUT" and "namespace_id" in body:
                con.execute(
                    "UPDATE projects SET namespace_id = ? WHERE name = ?",
                    (body["namespace_id"], name),
                )
            con.commit()
        finally:
            con.close()
        self._reply(201 if self.command == "POST" else 200, {"project": {"name": name}})

    do_POST = _handle
    do_PUT = _handle


class ProcessExitTest(unittest.TestCase):
    """C (process level): the script's real exit status, against real HTTP."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="cf356-proc-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.db = make_db(self.root / "scheduler.db", self.root / "lanes")

    def _run(self, *, refuse=None, refuse_all=0):
        state = {
            "db": str(self.db),
            "refuse": dict(refuse or {}),
            "refuse_all": refuse_all,
            "requests": [],
        }
        StubScheduler.state = state
        server = ThreadingHTTPServer(("127.0.0.1", 0), StubScheduler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            env = dict(
                os.environ,
                HOME=str(self.home),
                SCHEDULER_OPERATOR_TOKEN="stub-token",
                SCHEDULER_DB=str(self.db),
                SCHEDULER_API=f"http://127.0.0.1:{server.server_port}",
            )
            return subprocess.run(
                [sys.executable, "-B", str(SCRIPTS / "configure_family.py")],
                cwd=str(REPO),
                env=env,
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)

    def test_successful_run_exits_zero(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"targeted={len(SUFFIXES)}", result.stdout)
        self.assertIn("refused=0", result.stdout)

    def test_shortfall_exits_two_and_names_the_lane(self):
        result = self._run(refuse={"code-factory-docs": 500})
        self.assertEqual(
            result.returncode, configure_family.EXIT_SHORTFALL, result.stdout
        )
        self.assertIn("refused: code-factory-docs:", result.stderr)

    def test_every_lane_refused_exits_nonzero(self):
        result = self._run(refuse_all=500)
        self.assertEqual(result.returncode, configure_family.EXIT_SHORTFALL)
        refused = [
            line for line in result.stderr.splitlines() if line.startswith("refused: ")
        ]
        self.assertEqual(len(refused), len(SUFFIXES), result.stderr)

    def test_the_module_imports_without_a_token_or_a_database(self):
        probe = self.root / "import_probe.py"
        probe.write_text(
            "import sys\n"
            f"sys.path.insert(0, {str(SCRIPTS)!r})\n"
            "import configure_family\n"
            "print('IMPORT_OK', configure_family.PID)\n"
        )
        env = dict(os.environ, HOME=str(self.home))
        env.pop("SCHEDULER_OPERATOR_TOKEN", None)
        result = subprocess.run(
            [sys.executable, "-B", str(probe)],
            env=env,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        # F2-2 is preserved, not deleted: the hardcoded PID is still the default.
        self.assertIn("IMPORT_OK 1755676", result.stdout)


class RedControlTest(unittest.TestCase):
    """D: the pre-fix body exits 0 with zero lanes configured."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="cf356-red-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.home = self.root / "home"
        (self.home / ".hermes" / "coding-hermes").mkdir(parents=True)
        (self.home / "code-factory" / "prompts").mkdir(parents=True)
        self.db = make_db(
            self.home / ".hermes" / "coding-hermes" / "scheduler.db",
            self.root / "lanes",
        )

    def test_prefix_body_exits_zero_with_every_lane_unconfigured(self):
        prefix = self.root / "configure_family_prefix.py"
        rev = PrefixSource.materialise(prefix)
        driver = self.root / "prefix_driver.py"
        driver.write_text(PrefixSource.DRIVER)
        env = dict(os.environ, HOME=str(self.home))
        env.pop("SCHEDULER_OPERATOR_TOKEN", None)
        result = subprocess.run(
            [sys.executable, "-B", str(driver), str(prefix), str(SCRIPTS)],
            cwd=str(REPO),
            env=env,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        self.assertEqual(result.returncode, 0, f"{rev}: {result.stderr}")
        self.assertIn("CONFIGURED=0", result.stdout, result.stdout)
        failed = int(result.stdout.split("FAILED=")[1].split()[0])
        self.assertEqual(failed, len(SUFFIXES))
        # Every refused create still calls con.commit() and returns None: exit 0.
        self.assertIn("failed:", result.stdout)
        con = connect(self.db)
        try:
            configured = con.execute(
                "SELECT COUNT(*) FROM projects WHERE name LIKE 'code-factory-%' "
                "AND parent = 'code-factory'"
            ).fetchone()[0]
        finally:
            con.close()
        self.assertEqual(configured, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
