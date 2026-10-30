#!/usr/bin/env python3
"""Semantic negative controls on private source copies, never on the live tree."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/inference-proxy.py"
TEST = ROOT / "tests/inference-contract.py"

# name, one exact source edit, focused real-boundary test, expected assertion text.
MUTATIONS = [
    (
        "scope",
        'require(all(body[k] == identity[k] for k in SCOPE), "denied")',
        "require(True)",
        "test_denials_before_key_resolution",
        "200 != 403",
    ),
    (
        "expiry-revocation",
        'require(\n            not identity["revoked"] and identity["expires_at"] > time.time(), "denied"\n        )',
        "require(True)",
        "test_denials_before_key_resolution",
        "200 != 403",
    ),
    (
        "bearer-digest",
        'if hmac.compare_digest(item["token_hash"], token_hash)',
        "if True",
        "test_denials_before_key_resolution",
        "200 != 403",
    ),
    (
        "model-allowlist",
        'require(all(candidate in allowed for candidate in candidates), "denied")',
        "require(True)",
        "test_fallback_authorized_and_disallowed",
        "200 != 403",
    ),
    (
        "authorize-before-secret",
        'require(wire_valid, "denied")',
        'self.state.secret("provider.key"); require(wire_valid, "denied")',
        "test_denials_before_key_resolution",
        "denial resolved upstream credentials",
    ),
    (
        "attestation-signature",
        'require(\n        HEX.fullmatch(signature) is not None\n        and hmac.compare_digest(signature, expected),\n        "attestation",\n    )',
        "require(True)",
        "test_attestation_failures_and_error_sentinel",
        "200 != 502",
    ),
    (
        "served-pair",
        'require((provider, model) == (route["provider"], route["model"]), "attestation")',
        "require(True)",
        "test_attestation_failures_and_error_sentinel",
        "200 != 502",
    ),
    (
        "response-credential-echo",
        'require(key not in content and attestation_key not in content, "upstream")',
        "require(True)",
        "test_attestation_failures_and_error_sentinel",
        "upstream credential leaked to client",
    ),
    (
        "private-mode",
        "and stat.S_IMODE(info.st_mode) == 0o600\n            )",
        ")",
        "test_host_files_and_policy_fail_closed",
        "200 != 403",
    ),
    (
        "single-link",
        "stat.S_ISREG(info.st_mode)\n                and info.st_nlink == 1",
        "stat.S_ISREG(info.st_mode)",
        "test_host_files_and_policy_fail_closed",
        "200 != 502",
    ),
    (
        "no-follow",
        "flags | os.O_NOFOLLOW | os.O_NONBLOCK",
        "flags | os.O_NONBLOCK",
        "test_host_files_and_policy_fail_closed",
        "200 != 502",
    ),
    (
        "success-evidence",
        'self.evidence.append(\n                    request_id,\n                    scope,\n                    requested,\n                    attempted,\n                    served,\n                    "success",\n                    "hmac-sha256-trusted-adapter-v1",\n                )',
        "pass",
        "test_http_success_and_evidence",
        "success",
    ),
    (
        "evidence-fsync",
        "os.fsync(self.fd)\n            self.seq += 1",
        "self.seq += 1",
        "test_evidence_write_failure_before_key_and_success",
        "200 != 503",
    ),
    (
        "evidence-integrity",
        'require(\n                    type(claimed) is str\n                    and hmac.compare_digest(claimed, digest(canonical(row))),\n                    "evidence",\n                )',
        "require(True)",
        "test_restart_revocation_rotation_and_corruption",
        "Exception not raised",
    ),
    (
        "redirect-denial",
        "return None\n\n\ndef attestation_payload",
        "return super().redirect_request(req, fp, code, msg, headers, newurl)\n\n\ndef attestation_payload",
        "test_redirect_and_environment_proxy_not_forwarded",
        "provider credential followed redirect/environment proxy",
    ),
    (
        "environment-proxy",
        "urllib.request.ProxyHandler({})",
        "urllib.request.ProxyHandler()",
        "test_redirect_and_environment_proxy_not_forwarded",
        "provider credential followed redirect/environment proxy",
    ),
]


def run(source, test=None):
    args = [sys.executable, "-B", str(TEST)]
    if test:
        args.append("InferenceContract." + test)
    return subprocess.run(
        args,
        env=dict(
            os.environ, CF_INFERENCE_UNDER_TEST=str(source), PYTHONDONTWRITEBYTECODE="1"
        ),
        capture_output=True,
        text=True,
        timeout=90,
    )


def main():
    control = run(SOURCE)
    if control.returncode:
        sys.exit("FAIL unchanged inference control\n" + control.stdout + control.stderr)
    count = re.search(r"Ran ([0-9]+) tests", control.stderr)
    if count is None:
        sys.exit("FAIL unchanged control missing executed test count")
    print("PASS unchanged real-boundary control (" + count[1] + " tests)", flush=True)
    text = SOURCE.read_text()
    with tempfile.TemporaryDirectory(prefix="cf-inference-mutations-") as directory:
        directory = Path(directory)
        for name, old, new, test, expected in MUTATIONS:
            if text.count(old) != 1:
                sys.exit("FAIL mutation anchor: " + name)
            mutant = directory / (name + ".py")
            changed = text.replace(old, new)
            compile(changed, str(mutant), "exec")
            mutant.write_text(changed)
            result = run(mutant, test)
            output = result.stdout + result.stderr
            if (
                result.returncode != 1
                or "AssertionError" not in output
                or expected not in output
                or "FAILED (failures=" not in output
                or "ERROR:" in output
            ):
                sys.exit(
                    "FAIL mutation survived or bootstrap-only: " + name + "\n" + output
                )
            print(
                "PASS semantic mutation rejected: " + name + " (" + expected + ")",
                flush=True,
            )
        # Real selftest must propagate a failed inference suite, not just name it.
        scratch = directory / "repository"
        shutil.copytree(
            ROOT,
            scratch,
            ignore=shutil.ignore_patterns(".git", ".gitreins", "__pycache__"),
        )
        (scratch / "tests/inference-contract.py").write_text(
            'import sys\nprint("FAIL injected inference-contract")\nsys.exit(23)\n'
        )
        result = subprocess.run(
            ["bash", str(scratch / "tests/selftest.sh")],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if (
            result.returncode == 0
            or "FAIL injected inference-contract" not in result.stdout
            or "SELFTEST: FAIL" not in result.stdout
        ):
            sys.exit(
                "FAIL selftest inference failure propagation\n"
                + result.stdout
                + result.stderr
            )
        print("PASS selftest propagated inference exit 23", flush=True)
    print(
        "INFERENCE MUTATIONS: PASS ("
        + str(len(MUTATIONS))
        + " semantic mutants + selftest propagation)"
    )


if __name__ == "__main__":
    main()
