"""Exercise real battery red branches in a scratch copy, without live harnesses or DuckBrain.

The vars fixture hides one variable from the adapter's help and receipt, not real runtime
variable consumption. Memory mutations simulate a defective local writer; no live node,
transport, or DuckBrain is tested.
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def sandbox(tmp_path):
    for directory in ("tests", "scripts", "specs", "home", "adapters"):
        (tmp_path / directory).mkdir()
    shutil.copy2(ROOT / "tests/harness-conformance.sh", tmp_path / "tests")
    shutil.copy2(ROOT / "scripts/lib.sh", tmp_path / "scripts")
    shutil.copytree(
        ROOT / "scripts/harness",
        tmp_path / "scripts/harness",
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    shutil.copy2(ROOT / "specs/HARNESS-MATRIX.md", tmp_path / "specs")
    return tmp_path


def run_battery(root, *args):
    env = {
        "PATH": os.environ["PATH"],
        "HOME": str(root / "home"),
        "TMPDIR": str(root),
        "LANG": "C",
        "HC_WORK_ROOT": str(root / "home/work"),
    }
    return subprocess.run(
        ["bash", str(root / "tests/harness-conformance.sh"), *args],
        env=env,
        text=True,
        capture_output=True,
        timeout=60,
    )


def row(result, name, verdict):
    matches = [
        line.strip()
        for line in result.stdout.splitlines()
        if f"{verdict}  {name} " in line
    ]
    assert len(matches) == 1, result.stdout + result.stderr
    print(matches[0])
    return matches[0]


def test_vars_red_and_restored(sandbox):
    adapter = sandbox / "adapters/install-hermes.sh"
    real = sandbox / "scripts/harness/install-hermes.sh"
    wrapper = '#!/usr/bin/env bash\nset -o pipefail\nbash "{}" "$@" | sed s/CF_LANE/REMOVED_LANE/g\n'.format(
        real
    )
    adapter.write_text(wrapper)
    args = ("--vars-only", "--only", "hermes", "--adapter-dir", str(adapter.parent))
    red = run_battery(sandbox, *args)
    assert red.returncode == 1, red.stdout + red.stderr
    assert "CF_LANE" in row(red, "hermes:vars", "FAIL")
    adapter.write_text(wrapper.replace("sed s/CF_LANE/REMOVED_LANE/g", "cat"))
    green = run_battery(sandbox, *args)
    assert green.returncode == 0, green.stdout + green.stderr
    row(green, "hermes:vars", "PASS")


@pytest.mark.parametrize("failure", ["accepted", "wrote"])
def test_memory_red_and_restored(sandbox, failure):
    writer = sandbox / "scripts/harness/harness_memory.py"
    original = writer.read_text()
    anchor = "    args = _parser().parse_args(argv)\n"
    assert original.count(anchor) == 1
    if failure == "accepted":
        injected = '    if args.action == "records" and not args.namespace:\n        return 0\n'
    else:
        injected = '    if args.action == "records" and not args.namespace:\n        Path(args.r1_backend).write_text("unexpected")\n        return 1\n'
    writer.write_text(original.replace(anchor, anchor + injected))
    red = run_battery(sandbox, "--memory-only", "--only", "hermes")
    assert red.returncode == 1, red.stdout + red.stderr
    message = row(red, "hermes:memory-negative", "FAIL")
    assert (
        "missing namespace was accepted"
        if failure == "accepted"
        else "missing namespace wrote a record"
    ) in message
    writer.write_text(original)
    green = run_battery(sandbox, "--memory-only", "--only", "hermes")
    assert green.returncode == 0, green.stdout + green.stderr
    row(green, "hermes:memory-negative", "PASS")
