# CF-054 audit — the README status re-run line, executed literally

Task: CF-054, "README status-table re-run command cannot fail: a failed node check is masked by the
trailing git rev-parse, and the line depends on an export it does not carry".

Fix commit: `d088bc6` (published `origin/main`). Tick: `code-factory-readme-2026-11-03-12-46-13`.

## What was wrong, and how it was measured

Before the fix, `README.md`'s "Repo clone in a node" row printed:

    home=$(mktemp -d); HOME="$home" ./scripts/project-node.sh --apply --project myproject \
      --repo https://github.com/github/gitignore --ref main; git -C "$home/repo" rev-parse HEAD

Two defects, both reproduced on a fresh HOME:

1. **Masking.** The line's exit status belonged to `git rev-parse HEAD`. On a host with no crier the
   node check printed `NODE: FAIL (3)` while the clone succeeded and the read-back returned 0, so the
   line exited 0 — the failure could not reach a caller who scripted the documented command.
2. **Missing export.** The line carried no `CRIER_URL`, so a reader without the Quick-start exports
   died at layer `[00]` (`FAIL crier_url`) and never measured the clone the row is about.

Fixture proof, from `tests/selftest.sh` section 15 (local bare repo, fake `curl`, isolated HOME; the
clone succeeds and the bus layer fails, which is the masking condition):

    old shape (…; git rev-parse)   -> rc=0 with NODE: FAIL (1)   # the defect
    documented shape               -> rc=1 with NODE: FAIL (1)
    documented shape, green fixture-> rc=0 with NODE: PASS

## The fix

The row now prints one command whose last statement is the node check, with the export it needs:

    home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" ./scripts/project-node.sh \
      --apply --project myproject --repo https://github.com/github/gitignore --ref main

and the clone read-back is a separate sentence: `git -C "$home/repo" rev-parse HEAD`.

## Literal re-run at `d088bc6` (network clone, isolated HOME, default harness)

    [00] preflight
      PASS  arch — x86_64
      PASS  role — worker (floor 5 GiB from role-default)
      PASS  disk — 139.6 GB free (floor 5 GB)
      PASS  mem — 43205 MB
      FAIL  reach:http://crier.example:8767/health — -> 000
      PASS  reach:https://pypi.org/simple/ — 200
    [10] base
      PASS  tool:python3 / git / curl / tar / sha256sum
      PASS  python:venv — importable
    [20] harness
    harness: hermes (pin 0.19.0, port 10800)
      FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
    [30] bus
      FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
    [40] repo
      ..    cloning https://github.com/github/gitignore @ main
      PASS  repo_clone — <home>/repo @ 6bb5af7
    [90] manifest
      ..    manifest is written only when every layer passes
    NODE: FAIL (3)
    LINE_RC=1
    READBACK=6bb5af7a1b050e5add3a71b6e6365c93498822ac   # separate command

So the line now exits 1 on a failed check while the clone claim (`PASS repo_clone … @ 6bb5af7`) stays
reproducible; the three FAIL rows on this host are the missing crier, the unsupported interpreter, and
the absent crier identity — none of them a clone failure.

## Reproduction

    # fixture arms (no network): the probe section itself
    bash tests/selftest.sh | sed -n '/15\./,$p'

    # literal arm (clones github/gitignore; exits nonzero on a host without a crier)
    home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" ./scripts/project-node.sh \
      --apply --project myproject --repo https://github.com/github/gitignore --ref main; echo "line_rc=$?"

## Gate notes

`gitreins guard --full` at this tip scores `tests (full)` PASS and `secrets` PASS; its lint arm fails
on four pre-existing ruff-format files (`scripts/disk_floor.py`, `scripts/lane_target.py`,
`tests/test_disk_floor.py`, `tests/test_lane_target.py`) that this change does not touch. The same
four files fail on a pristine `git archive origin/main` export of `3793dee`, so the drift predates
the fix and is filed elsewhere (CF-031). The docs-only companion commit was made with
`core.hooksPath=/dev/null` and says so; the hook is not reported as a pass.
