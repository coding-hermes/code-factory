"""CF-247 — a bunker exec budget above the 300 s client stream ceiling is refused.

`bunker exec` is one gRPC call whose client deadline is a fixed 300 s. The probe
scripts used to spend `--timeout` as a *subprocess* budget only, so `--timeout
900` looked honoured and then died at the client after five minutes, measuring
nothing (measured 2026-11-21: `--timeout 600 -- sh -c "sleep 330"` ->
deadline_exceeded at real 5m0.106s). The settling arm refuses up front, in both
CLIs, before any network call.

These tests pin the refusal three ways:

  1. up front   — non-zero exit and a message naming the flag, its value and the
                  ceiling, with the `bunker` binary on PATH never executed. The
                  stub writes a marker file when it runs; no marker is what makes
                  "silently truncated at 300 s" impossible rather than unlikely.
  2. permissive — a budget at/below the ceiling still reaches the probe (the stub
                  IS invoked, and no ceiling is mentioned), so the preflight is a
                  ceiling check and not a blanket refusal of `--timeout`.
  3. one number — the ceiling and its sentence are defined once, in
                  scripts/bunker_exec.py, and both CLIs import it. A second copy
                  of the literal is what let the flags drift from the deadline.

Run: python3 -m pytest tests/test_bunker_exec_ceiling.py -q
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
CEILING_MODULE = SCRIPTS / "bunker_exec.py"
FRESHNESS = SCRIPTS / "node_freshness.py"
SEED_DRIFT = SCRIPTS / "node_seed_drift.py"

CEILING = 300
OVER_CEILING = 900

# The two CLIs that hand their own --timeout to a `bunker exec` stream.
CLIS = [FRESHNESS, SEED_DRIFT]


def make_bunker_stub(directory: Path, marker: Path) -> dict:
    """A `bunker` on PATH that records the invocation and answers nothing useful.

    Exit 1 with a recognisable line: a probe that reaches the network fails on its
    own terms (unreachable), which is exactly what a permissive case asserts. The
    marker is the load-bearing part — it is written only if the binary ran.
    """
    binary = directory / "bunker"
    binary.write_text(
        "#!/bin/sh\n"
        f"printf '%s\\n' \"$*\" >> '{marker}'\n"
        "echo 'stub: no such agent' >&2\n"
        "exit 1\n"
    )
    binary.chmod(0o755)
    return dict(os.environ, PATH=f"{directory}{os.pathsep}{os.environ.get('PATH', '')}")


def run(script: Path, args, env):
    return subprocess.run(
        [sys.executable, str(script), *args],
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def node_args(timeout: int):
    return [
        "--agent",
        "cf-node",
        "--server",
        "stub-server",
        "--timeout",
        str(timeout),
    ]


def test_over_ceiling_is_refused_before_any_bunker_call(tmp_path):
    marker = tmp_path / "invoked"
    env = make_bunker_stub(tmp_path, marker)
    for script in CLIS:
        result = run(script, node_args(OVER_CEILING), env)
        out = result.stdout + result.stderr
        assert result.returncode != 0, f"{script.name} accepted {OVER_CEILING}s"
        # The refusal names the flag, the requested value and the ceiling.
        assert "--timeout" in out
        assert str(OVER_CEILING) in out
        assert str(CEILING) in out
        assert "ceiling" in out
        # ... and it happened before the network: the binary never ran.
        assert not marker.exists(), f"{script.name} invoked bunker above the ceiling"


def test_refusal_reports_the_value_the_ceiling_and_how_to_proceed(tmp_path):
    marker = tmp_path / "invoked"
    env = make_bunker_stub(tmp_path, marker)
    result = run(FRESHNESS, node_args(OVER_CEILING), env)
    message = result.stderr
    assert result.returncode == 2
    assert "--timeout 900 exceeds the bunker exec stream ceiling (300s)" in message, (
        message
    )
    # The fix an operator needs: stage and detach, or stay inside the budget.
    assert "detach" in message
    assert "<= 300s" in message


def test_budget_at_the_ceiling_reaches_the_probe(tmp_path):
    """300 s is usable: the preflight passes and the stub binary IS invoked."""
    marker = tmp_path / "invoked"
    env = make_bunker_stub(tmp_path, marker)
    for script in CLIS:
        result = run(script, node_args(CEILING), env)
        out = (result.stdout + result.stderr).lower()
        assert "ceiling" not in out, f"{script.name} refused the ceiling itself: {out}"
        assert marker.exists(), f"{script.name} never reached bunker at {CEILING}s"


def test_default_budget_still_reaches_the_probe(tmp_path):
    marker = tmp_path / "invoked"
    env = make_bunker_stub(tmp_path, marker)
    for script in CLIS:
        result = run(script, ["--agent", "cf-node", "--server", "stub-server"], env)
        out = (result.stdout + result.stderr).lower()
        assert "ceiling" not in out, f"{script.name} refused its own default budget"
        assert marker.exists(), f"{script.name} never reached bunker at the default"


def test_local_mode_is_not_capped_by_a_stream_it_never_opens(tmp_path):
    """Local mode spends --timeout as a subprocess budget: no exec stream, no refusal."""
    missing = tmp_path / "no-such-home"
    for script in CLIS:
        args = (
            ["--workdir", str(missing), "--timeout", str(OVER_CEILING)]
            if script is FRESHNESS
            else ["--home", str(missing), "--timeout", str(OVER_CEILING)]
        )
        result = run(script, args, dict(os.environ))
        out = (result.stdout + result.stderr).lower()
        assert "ceiling" not in out, f"{script.name} refused a local budget: {out}"


def test_help_states_the_ceiling_and_the_refusal():
    for script in CLIS:
        result = run(script, ["--help"], dict(os.environ))
        assert result.returncode == 0
        assert str(CEILING) in result.stdout
        assert "refused" in result.stdout.lower()


def test_ceiling_is_defined_once_and_both_clis_import_it():
    """A second copy of the literal is how a flag drifts from the deadline."""
    defining = [
        path
        for path in SCRIPTS.glob("*.py")
        if "BUNKER_EXEC_CEILING_S = " in path.read_text(encoding="utf-8")
    ]
    assert defining == [CEILING_MODULE], defining
    for script in CLIS:
        source = script.read_text(encoding="utf-8")
        assert "import bunker_exec" in source, script.name
        assert "bunker_exec.exceeds_ceiling(" in source, script.name
        assert "bunker_exec.ceiling_error(" in source, script.name


def test_ceiling_module_matches_the_measured_deadline():
    """The number is the measured one: 300 s, and nothing above it is usable."""
    source = CEILING_MODULE.read_text(encoding="utf-8")
    assert "BUNKER_EXEC_CEILING_S = 300" in source

    sys.path.insert(0, str(SCRIPTS))
    try:
        import bunker_exec
    finally:
        sys.path.pop(0)
    assert bunker_exec.BUNKER_EXEC_CEILING_S == CEILING
    assert not bunker_exec.exceeds_ceiling(CEILING)
    assert bunker_exec.exceeds_ceiling(CEILING + 1)
    message = bunker_exec.ceiling_error("--timeout", OVER_CEILING)
    assert str(OVER_CEILING) in message
    assert str(CEILING) in message


def test_missing_sibling_module_is_a_named_refusal(tmp_path):
    """A lone copy of the probe refuses BY NAME, not with a ModuleNotFound traceback.

    The ceiling is defined once, so `node_freshness.py` depends on its sibling
    `bunker_exec.py`. A layout that ships one without the other (a stray copy) must
    say so: a traceback buried in a provisioning stderr file reads as an unreadable
    probe, which is the ambiguity this row exists to remove.
    """
    lone = tmp_path / "scripts"
    lone.mkdir()
    shutil.copy(FRESHNESS, lone / "node_freshness.py")
    result = subprocess.run(
        [
            sys.executable,
            str(lone / "node_freshness.py"),
            "--workdir",
            str(tmp_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    combined = result.stdout + result.stderr
    assert result.returncode == 2, combined
    assert "RESULT: FAIL (missing sibling module" in result.stdout, result.stdout
    assert "bunker_exec.py" in combined
    assert "Traceback" not in combined, combined


def test_probe_writes_nothing_into_the_tree_it_grades(tmp_path):
    """A clean checkout must stay clean after the probe runs on it.

    The probe measures "is this checkout origin/main with no local edits", so any
    file it leaves behind becomes a finding about itself. The sibling import is the
    live hazard: without `sys.dont_write_bytecode` it drops `scripts/__pycache__/`
    into a clean clone and layer 40 turns a PASS into WARN ("a local edit on the
    node is a finding") — measured on the selftest's layer-40 fixture.
    """
    repo = tmp_path / "repo"
    origin = tmp_path / "origin.git"
    (repo / "scripts").mkdir(parents=True)
    shutil.copy(FRESHNESS, repo / "scripts" / "node_freshness.py")
    shutil.copy(CEILING_MODULE, repo / "scripts" / "bunker_exec.py")
    (repo / "a.txt").write_text("one\n")
    git = ["git", "-C", str(repo)]
    subprocess.run(git + ["init", "-q", "-b", "main"], check=True)
    subprocess.run(git + ["add", "."], check=True)
    subprocess.run(
        git
        + [
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@example.invalid",
            "commit",
            "-qm",
            "one",
        ],
        check=True,
    )
    subprocess.run(["git", "init", "-q", "--bare", str(origin)], check=True)
    subprocess.run(git + ["remote", "add", "origin", str(origin)], check=True)
    subprocess.run(git + ["push", "-q", "origin", "main"], check=True)
    subprocess.run(git + ["fetch", "-q", "origin"], check=True)

    before = sorted(
        p.relative_to(repo) for p in repo.rglob("*") if ".git" not in p.parts
    )
    result = run(
        repo / "scripts" / "node_freshness.py",
        ["--workdir", str(repo)],
        {
            # The harness itself may run under PYTHONDONTWRITEBYTECODE=1
            # (tests/selftest.sh does), which would make this arm vacuous: it could
            # never observe the cache the probe is supposed to avoid. The child runs
            # WITHOUT it, so the only thing preventing the write is the probe's own
            # `sys.dont_write_bytecode`.
            k: v
            for k, v in os.environ.items()
            if k != "PYTHONDONTWRITEBYTECODE"
        },
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "RESULT: PASS" in result.stdout, result.stdout
    after = sorted(
        p.relative_to(repo) for p in repo.rglob("*") if ".git" not in p.parts
    )
    assert after == before, f"the probe left {set(after) - set(before)} behind"


def main() -> int:
    """Run every `test_*` function without pytest.

    `tests/selftest.sh` invokes test files as plain scripts, where a pytest-only
    module exits 0 having run NOTHING — a vacuous PASS that looks exactly like a
    green gate. This runner is what makes that row real: it discovers the tests,
    supplies a scratch directory to the ones that ask for one, and fails on any
    exception. pytest still discovers the same functions normally.
    """
    import inspect
    import tempfile
    import traceback

    tests = [
        (name, fn)
        for name, fn in sorted(globals().items())
        if name.startswith("test_") and callable(fn)
    ]
    failures = 0
    for name, fn in tests:
        try:
            wants_dir = len(inspect.signature(fn).parameters) == 1
            if wants_dir:
                with tempfile.TemporaryDirectory() as scratch:
                    fn(Path(scratch))
            else:
                fn()
        except Exception:  # noqa: BLE001 — a standalone runner reports, never masks
            failures += 1
            print(f"FAIL  {name}")
            traceback.print_exc()
        else:
            print(f"PASS  {name}")
    print(f"{len(tests) - failures}/{len(tests)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
