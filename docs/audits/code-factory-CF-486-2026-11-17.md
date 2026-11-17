# CF-486 — the evidence checker accepts both `detail.evidence` shapes

Row: **CF-486** · chapter changed: **III.M4.S7** (`docs/handbook/chapters/M4-board.md` §7)
· measured at the pre-fix tip `d015ad67c78efd02956879ceb450262399ab0127`, fix in the commit
that carries this file.

## The defect

`scripts/board_evidence_check.py` read `detail.evidence` only as a LIST of `{"run_id": ...}`
pointers (`_evidence_ids`, line 170 at the pre-fix tip). A `boardctl` closeout writes the DICT
bundle `{commit, commands, artifacts}`, so CF-473 — closed legitimately, with a bundle naming
commit `5c79c29c` and artifact `docs/audits/code-factory-CF-473-2026-11-16.md` — was reported
`ZERO-EVIDENCE`. The tracked suite's allowlist arm
(`tests/test_board_evidence_check.py:242`) refuses to absorb a new zero-evidence row, so the
suite went red at the published tip on a closeout nobody doubted.

## The measurement pair

Same worktree, same commands, only the checker differs. The NEW test file is present in both
arms, so the arm that discriminates is the shape rule, not a fixture:

| arm | checker | command | result |
|---|---|---|---|
| baseline (pre-fix) | pre-fix `_evidence_ids` | `python3 -m unittest discover -s tests -p "test_*.py"` | `Ran 231 tests`, `FAILED (failures=1, skipped=5)`, `AssertionError: 'CF-473' not found in frozenset(...)` at `tests/test_board_evidence_check.py:242` |
| red control | pre-fix `_evidence_ids` + NEW test arm | `python3 -m unittest tests.test_board_evidence_check` | rc 1, `Ran 8 tests`, `FAILED (failures=2)` — the same CF-473 assertion plus the fixture-shape assertion |
| green arm | fixed checker + NEW test arm | `python3 -m unittest tests.test_board_evidence_check` | rc 0, `Ran 8 tests`, `OK` |
| full suite (fixed tree) | fixed checker | `python3 -m unittest discover -s tests -p "test_*.py"` | rc 0, `Ran 232 tests`, `OK (skipped=5)` |

Transcripts, verbatim, in this directory: [`cf486-red-control-red.txt`](cf486-red-control-red.txt),
[`cf486-red-control-green.txt`](cf486-red-control-green.txt) (`.txt`, not `.log`, because the
repository ignores `*.log`). The baseline arm was run in a
detached worktree at `d015ad67` (`git worktree add --detach … d015ad67`), never in the shared
checkout, so a sibling lane's working state could not enter the measurement.

## The six fixture verdicts (criterion 3)

One fixture board carries all six shapes; the arm prints every verdict, not only the failures:

```
CF-486-FIXTURE-LIST         = resolved        (list of run_id pointers)
CF-486-FIXTURE-DICT-ARTIFACT= resolved        (bundle whose artifact exists in the tree)
CF-486-FIXTURE-DICT-COMMIT  = resolved        (bundle whose commit the events store names)
CF-486-FIXTURE-DICT-DANGLING= unresolved      (bundle in which nothing resolves)
CF-486-FIXTURE-EMPTY-LIST   = zero-evidence
CF-486-FIXTURE-EMPTY-DICT   = zero-evidence
```

A dict bundle is ONE evidence record, so it is a finding only when none of its pointers is
inspectable here; a list row names independent runs and keeps the stricter every-pointer rule.
An empty list, an empty object, or a field that yields no pointer at all stays `ZERO-EVIDENCE`.

## The live census, before and after

`python3 scripts/board_evidence_check.py` on the fixed tree:

```
stores: events=…/.coding-hermes/board/events.jsonl history=…/.gitreins/history (182 run dirs)
checked 183 complete rows, 64 unresolved
ZERO-EVIDENCE CF-289
ZERO-EVIDENCE CF-305
ZERO-EVIDENCE P5G-34
ZERO-EVIDENCE CF-422
```

`CF-473` is absent from the output and absent from `ACCEPTED_UNRESOLVED`, which is unchanged —
the widening closes the finding, the allowlist does not absorb it. The 64 unresolved rows are
the accepted 62 plus `CF-470` and `PERF-018`, whose named runs live nowhere in this checkout
(population, not new debt — see the population rule in the module docstring and M4 §7).

## Where the rule is written

1. `scripts/board_evidence_check.py` module docstring — "EVIDENCE SHAPE RULE (CF-486)".
2. `docs/BOARD.md` § "Closure evidence shapes".
3. `docs/handbook/chapters/M4-board.md` §7 — the census row and the "Evidence-shape rule
   (2026-11-17, CF-486)" paragraph, re-measured against this checkout.

The code, the contract and the chapter carry the same three sentences: two accepted shapes,
`ZERO-EVIDENCE` for an empty field, `UNRESOLVED` for a bundle none of whose pointers resolves.
