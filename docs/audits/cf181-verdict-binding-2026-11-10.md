# CF-181 verdict binding evidence

This evidence records the audit instrument and its source-grounded result under the
M3.S3 commit-hooks-and-gates / M4.S2 board-copy comparison contract in
`docs/handbook/OUTLINE.md#M3-S3-M4-S2`, with the measured explanation retained as
M6 documentation evidence. It does not manufacture a replacement verdict or alter
`.coding-hermes/board`.

## Scope and repair direction

The durable repair direction is an audit/report change: distinguish a verdict artifact
that resolves at the requested ref from a pointer that has disappeared from that ref.
The instrument in `docs/audits/cf181-verdict-binding-sweep.py` now reports
`UNRESOLVABLE` pointers, non-verdict records, rows with resolving evidence, and the
orphaned bindings that it can actually inspect. Live re-judging is unavailable here,
and no external state was changed.

The exact CF-181 AC0 snapshot was measured at historical published tip `0e44db94`:
that tree had 50 complete rows and 22 verdict JSON pointers, with 21 verdict records
checked and one orphan. The currently published ref is `origin/main=bd21cc1f`; its
`.gitreins/history/` tree contains only two newer bundles, while the current board
points at 75 historical verdict JSON paths. Those paths are unresolvable at the
current ref, so the current run cannot honestly reproduce the old 21-artifact result.
The report preserves both measurements rather than relabeling missing artifacts as
passes.

## Required measurements

Historical AC0 reproduction at `0e44db94`:

```
ref=0e44db94 complete_rows=50
verdict_artifacts_checked=22
rows_with_resolving_evidence=22 rows_without=28
=== UNRESOLVABLE ===
unresolvable_pointers=0
non_verdict_records=1
=== ORPHANED ===
CF-077 run=410022a2 artifact=.gitreins/history/2026-11-03/410022a2/verdict.json commit=1dfb58b8aa passed=True
orphan_count=1
status=CLEAN
```

The current published ref measurement is deliberately different and source-grounded:

```
ref=origin/main complete_rows=127
verdict_artifacts_checked=0
rows_with_resolving_evidence=0 rows_without=127
...
unresolvable_pointers=74
non_verdict_records=1
=== ORPHANED ===
orphan_count=0
status=UNRESOLVED
```

The current result is caused by the measured removal of the published history bundles,
not by a clean verdict population. The instrument prints every missing pointer, including
CF-077, and marks the run `UNRESOLVED`.

The two bindings were measured independently:

```
git merge-base --is-ancestor 1dfb58b8aac966fa858e274992e01bad27d0632b origin/main
# exit 1

git merge-base --is-ancestor 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc origin/main
# exit 0
```

The historical verdict envelope contains `1dfb58b8aac966fa858e274992e01bad27d0632b`,
while the CF-077 board row contains
`1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc`.

## Red and positive fixture arms

Pre-change reproduction from the published parent (`973a5fe3`) was:

```
ref=origin/main complete_rows=127
verdict_artifacts_checked=0
=== ORPHANED ===
orphan_count=0
```

That was the false-clean arm: the old instrument silently skipped every missing
artifact. The fixed instrument's clean fixture prints `orphan_count=0`; the orphan
fixture prints exactly one named line and `orphan_count=1`:

```
ref=HEAD complete_rows=1
verdict_artifacts_checked=1
...
=== ORPHANED ===
CF-009 run=fixture artifact=docs/audits/fixtures/cf181-verdict-orphan.json commit=0000000000 passed=True
orphan_count=1
status=CLEAN
```

The positive fixture uses the on-ref commit and also reports `orphan_count=0`.

## Patch comparison boundary

No patch-equivalence repair is claimed. The measured comparison
`git diff 1dfb58b8 1232f7a0 --stat` is 13 files changed, 1,173 insertions and 44
deletions, including board/history, performance documentation, and
`tests/test_lane_target.py`; the targeted auth files have no diff in that command.
That comparison is not sufficient to assert that the two verdicts certify equivalent
commits, so this evidence uses the durable unresolved-pointer report instead.

## Gate commands

The focused sweep and both fixture arms were run from the repository root. The required
landing gates are run separately at the commit that carries this evidence:

```
bash scripts/boardctl validate
bash tests/selftest.sh
```

Trace: `ch:trace row=CF-181 spec=docs/handbook/OUTLINE.md#M3-S3-M4-S2 test=cf181-sweep-and-fixtures evidence=docs/audits/cf181-verdict-binding-2026-11-10.md witness=origin/main-and-0e44db94 verdict=none:worker-commit memory=none:foreman-closeout`
