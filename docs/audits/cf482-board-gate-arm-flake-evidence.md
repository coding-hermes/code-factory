# CF-482 — the board-gate arm's duplicate-id verdict is not reproducible from its own output

Measured on the code-factory readme lane tick `code-factory-readme-2026-11-17-02-40-53`,
third execution, at published tip `8d6ca1be7d49871f3800dffa9608a3353e99d64a`.

ch:trace row=CF-482 spec=docs/traceability-doctrine.md test=none:arm-is-a-section-loop-not-a-named-symbol doc=tests/selftest.sh prompt=none:lane-brief evidence=docs/audits/cf482-board-gate-arm-flake-evidence.md witness=none:local-two-run-differential-captured-here verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-11-17-02-40-53

## What was measured

Two runs of `bash tests/selftest.sh` on the SAME tree — one through the commit hook
(`gitreins guard --full`, test mode full) and one invoked directly seconds later — disagreed
on exactly one arm. `SELFTEST: FAIL (1)` in the hook run, `SELFTEST: PASS` / `EXIT=0` in the
direct run, with `7. the board is valid JSONL -> PASS 572/572 rows parse` in both.

Section 7b loops over nine malformed-board fixtures and decides each with the same three
conditions. The output each arm prints is `printf '%s\n' "$out"`, where `out` is the captured
`board_arm` output, so a reader can reconstruct the verdict:

    if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "  FAIL  $expected" \
      && printf '%s\n' "$out" | grep -Fxq '  FAIL  2 of 3 rows parse' \
      && ! printf '%s\n' "$out" | grep -q '^  PASS'; then
      say "  PASS  $arm fixture rejected, exit $rc"
    else
      say "  FAIL  $arm fixture escaped the board gate (exit $rc)"; fails=$((fails+1))
    fi

## Hook run — the arm failed (verbatim, section 7b)

```
  PASS  missing-id fixture rejected, exit 1
  FAIL  board line 2: missing id
  FAIL  2 of 3 rows parse
  FAIL  duplicate-id fixture escaped the board gate (exit 1)
  FAIL  board duplicate id 'CF-001': lines 1 and 2
  FAIL  2 of 3 rows parse
  PASS  bad-status fixture rejected, exit 1
```

## Direct run, same tree, minutes later — the same arm passed (verbatim)

```
  PASS  missing-id fixture rejected, exit 1
  FAIL  board line 2: missing id
  FAIL  2 of 3 rows parse
  PASS  duplicate-id fixture rejected, exit 1
  FAIL  board duplicate id 'CF-001': lines 1 and 2
  FAIL  2 of 3 rows parse
  PASS  bad-status fixture rejected, exit 1
```

The two blocks carry the same `rc=1`, the same expected FAIL row and the same
`FAIL  2 of 3 rows parse` row, and no `PASS` line from `board_arm` in either. Read against the
assertion above, both outputs satisfy all three conditions and both should have printed
`PASS`. One did not. The differing section blocks are byte-identical apart from the arm's own
verdict line, so the verdict cannot be reconstructed from the evidence the arm prints.

## What is NOT proven

The root cause is not established. Candidates not yet excluded: interpreter/`mktemp` state inside
the run, a stale `$tmpd` path, or the section's interaction with the DEBUG trap that records
section headings. This artifact records the differential, not a diagnosis; a fix that only makes
the arm green without explaining the two verdicts would leave the same trap in place.

## Why it matters beyond this lane

The failing verdict reds the whole suite, and the suite is the pre-commit hook, so on this host any
commit can be refused for a fixture the diff never touched. This pass hit exactly that: a
board-only diff was refused by the hook while the same tree passed a direct run.

## Reproduce

```bash
git archive 8d6ca1be | tar -x -C <scratch>/src   # published reference tree
cd <checkout-of-8d6ca1be>
bash tests/selftest.sh | sed -n '/^7b\./,/^8\./p'   # repeat a few times; compare the
                                                   # duplicate-id block's verdict line
```

Tier: T3 for the arm (two real suite runs, evidence captured above); T4 not reached because the
underlying timing/state dependency was not isolated to a single reproducible input.
