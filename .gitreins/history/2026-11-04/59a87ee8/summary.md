# Verdict: CF-129

**Task:** docs/BOARD.md: state which flag each board_drift.py leg reads, and prove it
**Evaluated:** 2026-11-04T02:58:32.867071
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ docs/BOARD.md no longer claims that --repo selects the repository resolving the ref: it states that --repo selects where the published bytes are read (scripts/board_drift.py:98,111) while HEAD and the ref resolve in --workdir (scripts/board_drift.py:167-172).: docs/BOARD.md:58-59 now reads 'the **published bytes** come from `--repo <path>` — `git -C <repo> show <ref>:<file>` (`scripts/board_drift.py:98,111`); `--repo` defaults to the workdir'; docs/BOARD.md:60-62 reads 'the **HEAD/ancestry leg** is measured in `--workdir` — `git rev-parse HEAD`, `git rev-parse --verify <ref>^{commit}` and `git merge-base --is-ancestor HEAD <ref>` all run with `-C <workdir>` (`scripts/board_drift.py:167–172`)'. Line 51 also now qualifies 'as resolved in the workdir'. The old false sentence is gone from BOARD.md/README.md (grep 'selects the repository resolving' and 'resolving the ref' -> no matches in docs/BOARD.md or README.md; the only hit is the audit doc quoting the old text as the claim being corrected). Code confirms the doc: scripts/board_drift.py:98 `repo = Path(args.repo)... if args.repo else workdir`, :111 `git(repo, "show", f"{args.ref}:{BOARD / name}")`, :165-172 ancestry probes all use `workdir`.
  ✓ A workdir without an origin/main ref, run as 'python3 scripts/board_drift.py check --workdir <A> --repo <repo-with-origin/main> --ref origin/main', prints 'FAIL HEAD ancestry' and 'RESULT: DRIFT'; the same run with --no-head prints 'RESULT: OK'. Transcript committed at docs/audits/code-factory-docs-2026-11-04-CF-129.md.: Independently reproduced: fixture /tmp/cf129eval/workdir built from origin/main board bytes, `git -C A rev-parse --verify origin/main` -> 'fatal: Needed a single revision'. ARM1 `python3 -B scripts/board_drift.py check --workdir A --repo /home/kara/code-factory --ref origin/main` printed 'FAIL  HEAD ancestry — git rev-parse --verify origin/main^{commit}: exit 128; fatal: Needed a single revision' and 'RESULT: DRIFT (1 failed)', ARM1_RC=1. ARM2 identical plus --no-head printed 'RESULT: OK', ARM2_RC=0. Transcript committed at docs/audits/code-factory-docs-2026-11-04-CF-129.md (section 3 'Measurement' contains the reproduction script and the ARM 1/ARM 2/ARM 3 transcript blocks matching the observed output).
  ✓ tests/selftest.sh exits 0 after the change.: Ran fresh: `bash tests/selftest.sh` in /home/kara/code-factory -> SELFTEST_RC=0, output tail 'SELFTEST: PASS' (arm 29 'a workdir board that is not the published board is named as drift (CF-114)' all sub-cases PASS).
All three criteria verified: BOARD.md now correctly splits --repo (published bytes, board_drift.py:98,111) from --workdir (HEAD/ancestry, :167-172), the DRIFT/OK arms reproduce exactly as documented with a committed transcript, and tests/selftest.sh exits 0.

## Summary

Judge Result: CF-129

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ docs/BOARD.md no longer claims that --repo selects the repository resolving the ref: it states that --repo selects where the published bytes are read (scripts/board_drift.py:98,111) while HEAD and the ref resolve in --workdir (scripts/board_drift.py:167-172).: docs/BOARD.md:58-59 now reads 'the **published bytes** come from `--repo <path>` — `git -C <repo> show <ref>:<file>` (`scripts/board_drift.py:98,111`); `--repo` defaults to the workdir'; docs/BOARD.md:60-62 reads 'the **HEAD/ancestry leg** is measured in `--workdir` — `git rev-parse HEAD`, `git rev-parse --verify <ref>^{commit}` and `git merge-base --is-ancestor HEAD <ref>` all run with `-C <workdir>` (`scripts/board_drift.py:167–172`)'. Line 51 also now qualifies 'as resolved in the workdir'. The old false sentence is gone from BOARD.md/README.md (grep 'selects the repository resolving' and 'resolving the ref' -> no matches in docs/BOARD.md or README.md; the only hit is the audit doc quoting the old text as the claim being corrected). Code confirms the doc: scripts/board_drift.py:98 `repo = Path(args.repo)... if args.repo else workdir`, :111 `git(repo, "show", f"{args.ref}:{BOARD / name}")`, :165-172 ancestry probes all use `workdir`.
  ✓ A workdir without an origin/main ref, run as 'python3 scripts/board_drift.py check --workdir <A> --repo <repo-with-origin/main> --ref origin/main', prints 'FAIL HEAD ancestry' and 'RESULT: DRIFT'; the same run with --no-head prints 'RESULT: OK'. Transcript committed at docs/audits/code-factory-docs-2026-11-04-CF-129.md.: Independently reproduced: fixture /tmp/cf129eval/workdir built from origin/main board bytes, `git -C A rev-parse --verify origin/main` -> 'fatal: Needed a single revision'. ARM1 `python3 -B scripts/board_drift.py check --workdir A --repo /home/kara/code-factory --ref origin/main` printed 'FAIL  HEAD ancestry — git rev-parse --verify origin/main^{commit}: exit 128; fatal: Needed a single revision' and 'RESULT: DRIFT (1 failed)', ARM1_RC=1. ARM2 identical plus --no-head printed 'RESULT: OK', ARM2_RC=0. Transcript committed at docs/audits/code-factory-docs-2026-11-04-CF-129.md (section 3 'Measurement' contains the reproduction script and the ARM 1/ARM 2/ARM 3 transcript blocks matching the observed output).
  ✓ tests/selftest.sh exits 0 after the change.: Ran fresh: `bash tests/selftest.sh` in /home/kara/code-factory -> SELFTEST_RC=0, output tail 'SELFTEST: PASS' (arm 29 'a workdir board that is not the published board is named as drift (CF-114)' all sub-cases PASS).
All three criteria verified: BOARD.md now correctly splits --repo (published bytes, board_drift.py:98,111) from --workdir (HEAD/ancestry, :167-172), the DRIFT/OK arms reproduce exactly as documented with a committed transcript, and tests/selftest.sh exits 0.

Overall: PASS ✓
