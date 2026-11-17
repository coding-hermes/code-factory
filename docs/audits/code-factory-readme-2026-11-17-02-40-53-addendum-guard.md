# Addendum — the guard red that blocked the CF-467/CF-468 commit, and why it is not that diff

Companion to `docs/audits/code-factory-readme-2026-11-17-02-40-53.md`. That artifact was frozen before
the commit; this one records what the commit hook returned afterwards.

## What the guard returned

`git -c core.hooksPath=/dev/null` was **not** used first: the commit ran the repository's real
pre-commit hook (`gitreins guard --quality-async`, `.git/hooks/pre-commit`) with `test_mode: full`.
Result, from `.gitreins/logs/guard-20261117T043145.043280Z.log`:

```
Tier 1 Guards: FAIL  (test mode: full)
  ✓ secrets — clean (gitleaks + builtin cross-check); scanners: nice=nice -n 10
  ~ lint — skipped (no staged files)
  ✗ tests (full) — EXIT=1
...
SELFTEST: FAIL (1)
```

One arm failed, and every earlier section passed, including the README arms this diff could have
touched — §9 (`every prompts/*.md named by README.md exists`), §28 (`census README/mirror byte
parity`), §30 (`README Status rows 1 and 3 cite the interpreter-qualified --check`), and §76 c
(`README Quick start names HERMES_PYTHON_BIN`).

## The failing arm

```
58. per-repo deploy key, node runtime, shared module cache, footprint, orphan reap (CF-003)
  FAIL  the CF-003 unit battery (tests/test_node_provisioning.py)
    | FAIL: test_working_room_shortfall_is_a_refusal (__main__.NodeFootprint...)
    |   File "…/tests/test_node_provisioning.py", line 580, in test_working_room_shortfall_is_a_refusal
    |     self.assertNotEqual(result.returncode, 0)
    | AssertionError: 0 == 0
    | Ran 24 tests … FAILED (failures=1)
```

The arm runs `node_hygiene.py footprint --working-room-mib 1000000` and requires a nonzero exit. Run
directly on this host it returns **0**:

```
  PASS  footprint — 0.0 MiB measured at /mnt/ssd/tmp/…
  PASS  footprint:room — 1000000.0 MiB required (0.0 MiB + 1000000 MiB working room),
                         1827240.5 MiB free, headroom 827240.5 MiB
EXIT=0
```

1,827,240.5 MiB ≈ 1.74 TiB free on the measured volume, so a 1,000,000 MiB demand is admitted and
the refusal branch is unreachable. The arm is unsatisfiable on **any** host with more than ~977 GiB
free — the fixture hard-codes a demand instead of deriving it from, or forcing, the volume it grades.

## Reproduction at the base, with the diff absent

```
$ git worktree add --detach /tmp/cf-base-verify 2e732112c52ec0de47ad8f921ae19b09e44b36d7
$ cd /tmp/cf-base-verify && grep -c 'twelve files for fourteen lanes' README.md
0
$ python3 -m unittest tests.test_node_provisioning.NodeFootprint.test_working_room_shortfall_is_a_refusal
FAIL: test_working_room_shortfall_is_a_refusal (…NodeFootprint…)
  File "/tmp/cf-base-verify/tests/test_node_provisioning.py", line 580, in …
    self.assertNotEqual(result.returncode, 0)
AssertionError: 0 == 0
FAILED (failures=1)
```

Same arm, same line, same assertion, at the published base tip, in a tree that does not carry this
commit. The red is therefore a host-condition gate failure, not a regression from the README diff —
which touched `README.md` and this audit pair only, with no test or script in the diff
(`git show --name-only --format= 4f3bd887`).

## Consequence taken

The commit landed with the guard allowed to run first, then with the documented bypass
(`git -c core.hooksPath=/dev/null commit`) and the failure disclosed in the commit body and on both
board rows as `guard=FAIL`. Filing the fixture repair is CF-479; this addendum is its evidence, and
the correct long-term fix is that row, not a bypass.

## Boundary note

This file was authored **after** the first commit was published. The first commit
(`4f3bd887d208922c211d5071ae15f8076140ed3a`, rebased from `8bd8c4d2` onto a sibling's `1f3a2583`) is
the implementation for CF-467 and CF-468; this addendum and the board rows ship in a second commit.
Neither commit rewrites the other's claims.
