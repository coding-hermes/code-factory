"""CF-507: the `--check` agent row measures the client's OUTPUT, not its exit status.

A bunker client that exits 0 and prints nothing used to certify
`PASS  agent — <id> exists ()` — empty parentheses, green row — and the run then went on to
probe a node it had never seen. Existence is the agent id appearing in `info`'s output; the
same run's `server` row already measures emptiness (`bunker list` must name the server), so
the two rows must not draw opposite conclusions from the same empty client.

Every arm below drives the REAL script with a stub client first on PATH, a throwaway HOME and
TMPDIR, and a minimal config: no network, no node, no credentials.
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "bunker-provision.sh"
AGENT = "demo-node"
SERVER = "fixture-server"


def client(info_body: str, info_status: int = 0) -> str:
    """A bunker client whose `info` prints `info_body` (or nothing) and exits `info_status`."""
    return (
        "#!/usr/bin/env bash\n"
        'case "$1" in\n'
        "  list) printf 'NAME  STATUS\\n%s  running\\n' \"$FIXTURE_SERVER\" ;;\n"
        f"  info) {info_body} exit {info_status} ;;\n"
        "  version) exit 0 ;;\n"
        "  cp|exec) exit 0 ;;\n"
        "esac\n"
        "exit 0\n"
    )


def run_check(stub: str) -> tuple[str, int]:
    """Run `bunker-provision.sh --check` with `stub` as the bunker client; return output+status."""
    with tempfile.TemporaryDirectory(prefix="cf507-") as directory:
        temp = Path(directory)
        bin_dir = temp / "bin"
        home = temp / "home"
        bin_dir.mkdir()
        home.mkdir()
        binary = bin_dir / "bunker"
        binary.write_text(stub)
        binary.chmod(0o755)
        config = temp / "cf.conf"
        config.write_text(f"PROJECT=demo\nAGENT={AGENT}\nSERVER={SERVER}\n")
        env = {
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "HOME": str(home),
            "TMPDIR": str(temp),
            "FIXTURE_SERVER": SERVER,
        }
        result = subprocess.run(
            ["/bin/bash", str(SCRIPT), "--config", str(config), "--check"],
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        )
        return result.stdout + result.stderr, result.returncode


def rows(output: str, verdict: str, label: str) -> list[str]:
    """Every `  <verdict>  <label> — …` row in the run."""
    prefix = f"  {verdict}  {label} — "
    return [line for line in output.splitlines() if line.startswith(prefix)]


def test_hollow_client_fails_the_agent_row_and_quotes_the_emptiness() -> None:
    output, status = run_check(client("", 0))
    agent_rows = rows(output, "PASS", "agent") + rows(output, "FAIL", "agent")
    assert len(agent_rows) == 1, (
        f"expected exactly one agent row, got {agent_rows}\n{output}"
    )
    row = agent_rows[0]
    assert row.startswith("  FAIL  agent — "), row
    # The row must quote a MEASURED number, not a guess.
    assert "0 bytes" in row, row
    assert "does not name the agent" in row, row
    assert AGENT in row, row
    assert status != 0, (
        f"a hollow client turned the gate green (exit {status})\n{output}"
    )


def test_hollow_client_stops_before_the_node_probe() -> None:
    """An unproven agent is not probed: the rows a real client never reaches stay unrun."""
    output, _ = run_check(client("", 0))
    assert not rows(output, "PASS", "agent"), output
    assert not rows(output, "FAIL", "repo"), (
        "the run probed a node it never saw — the agent row must fail closed\n" + output
    )


def test_naming_client_passes_the_agent_row() -> None:
    output, _ = run_check(client('printf "agent %s 6h\\n" "$2";', 0))
    passed = rows(output, "PASS", "agent")
    assert len(passed) == 1, f"expected one PASS agent row, got {passed}\n{output}"
    assert AGENT in passed[0], passed[0]
    assert not rows(output, "FAIL", "agent"), output


def test_non_zero_exit_keeps_the_absent_wording() -> None:
    output, status = run_check(client("", 1))
    failed = rows(output, "FAIL", "agent")
    assert len(failed) == 1, f"expected one FAIL agent row, got {failed}\n{output}"
    assert "absent — run --apply to create it" in failed[0], failed[0]
    assert status != 0, output
