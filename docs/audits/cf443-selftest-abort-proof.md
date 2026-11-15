# CF-443 selftest abort attribution proof

This artifact is the committed, re-runnable evidence for CF-443. It proves the
failure path required by AGENTS.md rule 2: an unexpected selftest abort is a
named failure, not `SELFTEST: FAIL (0)`.

## Reproduce the abort shape

Run from the repository root:

    bash docs/audits/cf443-selftest-abort-proof.sh

The proof script copies `tests/selftest.sh` and `scripts/lib.sh` into a
throwaway directory, injects `cf443-broken.sh` into section 1, and makes the
section-1 `bash -n` command fail-fast in the copied probe. It does not modify
the checkout. The injected fixture is intentionally invalid shell:

    # deliberately invalid shell fixture
    if true; then

Observed output (exit code 0 for the proof script, whose child probe exits 1):

    1. every script parses
    .../cf443-broken.sh: line 3: syntax error: unexpected end of file from `if' command on line 2
    SELFTEST: ABORT section=1. every script parses command=bash -n "$f" rc=2
    SELFTEST: FAIL (1)
    EXIT=1
    proof_rc=1

The child selftest exit code is 1, and the proof asserts all of the following:
`SELFTEST: ABORT`, section 1, the `bash -n` command, the fixture name, and a
positive `SELFTEST: FAIL (n)` count. The command is represented by its shell
form; the diagnostic from that command names the expanded fixture path.

## Implementation behavior

`tests/selftest.sh` records the last command in a DEBUG trap and tracks the last
numeric section heading. The EXIT trap emits:

    SELFTEST: ABORT section=<last section> command=<last command> rc=<status>

before the final failure line. An unexpected abort with no previously counted
FAIL row is counted as one failure, so `SELFTEST: FAIL (0)` is impossible.
Expected negative-fixture `FAIL` rows remain ordinary captured output and do not
become suite failures.

## Historical evidence

The three foreman runs reported `SELFTEST: PASS`, exit code 0, with no suite
FAIL rows: runs at `ad9ad220` and `92725850` (the third run was the repeated
foreman reading at the same published selection). The two independent tier-2
judge aborts reported `SELFTEST: FAIL (0)`, exit code 1, during section 1 at
`bash -n scripts/bunker-provision.sh`; neither printed a named FAIL row. The
board reasoning records those judge findings at the published selection,
including the second judge tip `eb02981a`.

The difference was reproduced as a fail-fast environment-sensitive path, not
as a clean-tip source defect: the committed proof names `BASH_ENV` as the
injected variable and uses a hermetic throwaway cwd. It does not claim that
`PATH` or the shell binary caused the historical result. With the normal
published source and no injected `BASH_ENV`, the current tip passes.

## Verification at this change

    bash docs/audits/cf443-selftest-abort-proof.sh
    -> exit 0 (child proof_rc=1; output above)

    bash tests/selftest.sh
    -> exit 0
    -> SELFTEST: PASS
    -> EXIT=0
    -> no `^  FAIL` suite rows (fixture text containing FAIL is expected)

    scripts/boardctl validate
    -> RESULT: OK

Traceability:

    ch:trace row=CF-443 spec=docs/handbook/OUTLINE.md#M4-board test=docs/audits/cf443-selftest-abort-proof.sh doc=docs/audits/cf443-selftest-abort-proof.md verdict=worker-local-proof commit=worker-commit

The final commit message names AGENTS.md rule 2. The commit field above is
intentionally a pre-commit worker value; the foreman may replace it with the
actual landed commit hash during closeout.
