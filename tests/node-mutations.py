#!/usr/bin/env python3
"""Executable mutation controls on private local copies, never on live nodes."""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(root, test):
    return subprocess.run(
        [sys.executable, str(root / "tests/node-contract.py"), "NodeContract." + test],
        capture_output=True,
        text=True,
        timeout=60,
    )


def baseline(revision):
    """Reproduce historical defects without touching the checkout or credentials."""
    with tempfile.TemporaryDirectory(prefix="cf005-baseline-local-") as tmp:
        root = Path(tmp)
        shutil.copytree(ROOT / "scripts", root / "scripts")
        (root / "tests").mkdir()
        shutil.copy(ROOT / "tests/node-contract.py", root / "tests/node-contract.py")
        for relative in (
            "scripts/project-node.sh",
            "scripts/node-create.sh",
            "scripts/verify-node.sh",
        ):
            source = subprocess.run(
                ["git", "show", f"{revision}:{relative}"],
                cwd=ROOT,
                check=True,
                capture_output=True,
            ).stdout
            (root / relative).write_bytes(source)
        for test in (
            "test_creator_preconditions_and_exact_triple",
            "test_forbidden_manifest_paths_without_dispatch_option",
            "test_manifest_write_failure",
            "test_manifest_identity_and_byte_idempotence",
        ):
            result = run(root, test)
            output = result.stdout + result.stderr
            if result.returncode == 0 or "AssertionError" not in output:
                raise RuntimeError(f"baseline defect not reproduced: {test}\n{output}")
            print(
                f"BASELINE {revision} {test}: exit={result.returncode} assertion failure reproduced"
            )
        # Reproduce the old selftest oracle exactly, with a temporary HOME only.
        env = {"PATH": "/nonexistent", "HOME": str(root), "NODE_PROJECT": "t"}
        result = subprocess.run(
            ["/bin/bash", str(root / "scripts/project-node.sh"), "--check"],
            env=env,
            capture_output=True,
            text=True,
        )
        output = result.stdout + result.stderr
        if (
            result.returncode == 0
            or "FAILED: unbound variable" not in output
            or "FAIL" not in output
        ):
            raise RuntimeError("baseline bootstrap false green not reproduced")
        print(
            f"BASELINE bootstrap: exit={result.returncode}; substring FAIL accepted FAILED: unbound variable"
        )


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--baseline":
        baseline(sys.argv[2])
        return
    if len(sys.argv) != 1:
        raise ValueError("usage: node-mutations.py [--baseline REV]")
    mutations = [
        (
            "named-failure-removed",
            "scripts/project-node.sh",
            'bad "crier_url"',
            'ok "crier_url"',
            "test_named_check",
        ),
        (
            "bootstrap-error-decoy",
            "scripts/project-node.sh",
            None,
            '#!/bin/bash\necho "FAILED: unbound variable" >&2\nexit 1\n',
            "test_named_check",
        ),
        (
            "repo-precondition-removed",
            "scripts/node-contract.py",
            "re.fullmatch(REPO, repo),",
            "True,",
            "test_creator_preconditions_and_exact_triple",
        ),
        (
            "artifact-local-scope-removed",
            "scripts/node-contract.py",
            '    elif action == "artifact-path":\n        artifact_path(*args)',
            '    elif action == "artifact-path":\n        pass',
            "test_artifact_denials_before_remote_shell",
        ),
        (
            "artifact-nofollow-removed",
            "scripts/node-contract.py",
            " | os.O_NOFOLLOW",
            "",
            "test_artifact_symlink_hardlink_and_positive",
        ),
        (
            "manifest-write-status-ignored",
            "scripts/project-node.sh",
            '"${harness_version:-unknown}"; then',
            '"${harness_version:-unknown}"; true; then',
            "test_manifest_writer_error_is_not_pass",
        ),
        (
            "manifest-identity-ignored",
            "scripts/node-contract.py",
            "require(data.get(key) == expected[key],",
            "require(True,",
            "test_manifest_identity_and_byte_idempotence",
        ),
    ]
    for name, relative, old, new, test in mutations:
        with tempfile.TemporaryDirectory(prefix="cf005-mutation-local-") as tmp:
            root = Path(tmp)
            shutil.copytree(ROOT / "scripts", root / "scripts")
            (root / "tests").mkdir()
            shutil.copy(
                ROOT / "tests/node-contract.py", root / "tests/node-contract.py"
            )
            control = run(root, test)
            if control.returncode != 0:
                raise RuntimeError(
                    f"{name}: unchanged positive control failed\n{control.stdout}{control.stderr}"
                )
            path = root / relative
            source = path.read_text()
            if old is None:
                path.write_text(new)
            else:
                if old not in source:
                    raise RuntimeError(f"{name}: mutation target absent")
                path.write_text(source.replace(old, new))
            result = run(root, test)
            output = result.stdout + result.stderr
            # Assertion failure, not a shell/Python parse or bootstrap error in the test runner.
            if (
                result.returncode == 0
                or f"FAIL: {test}" not in output
                or "AssertionError" not in output
            ):
                raise RuntimeError(
                    f"{name}: mutation not detected by assertion\n{output}"
                )
            print(
                f"PASS local mutation {name}: control=0 mutant={result.returncode} assertion={test}"
            )
    print(
        f"MUTATIONS: PASS ({len(mutations)} local executable controls; no live proof)"
    )


if __name__ == "__main__":
    main()
