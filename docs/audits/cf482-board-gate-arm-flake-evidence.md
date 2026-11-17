# CF-482 — the board-gate arm's verdict was not a function of its own evidence

**Version 2** (v1 recorded the differential only, with no diagnosis). Measured on the
`code-factory` readme lane tick `code-factory-readme-2026-11-17-02-40-53`.

- v1 differential: published tip `8d6ca1be7d49871f3800dffa9608a3353e99d64a`, third execution.
- v2 mechanism + fix: published tip `ca013e7c54fd0b284b3a40ca77e28693192669da`, fifth execution.

This artifact deliberately carries no trace marker of its own: the row's single marker lives on
CF-482, and a second copy here would give one row two markers that no census can arbitrate.

## 1. What was measured (v1, unchanged)

Two runs of `bash tests/selftest.sh` on the SAME tree — one through the commit hook
(`gitreins guard --full`, test mode full) and one invoked directly seconds later — disagreed on
exactly one arm. `SELFTEST: FAIL (1)` in the hook run, `SELFTEST: PASS` / `EXIT=0` in the direct
run, with `7. the board is valid JSONL -> PASS 572/572 rows parse` in both.

Section 7b loops over nine malformed-board fixtures and decided each with the same three
conditions, re-derived inline:

    if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "  FAIL  $expected" \
      && printf '%s\n' "$out" | grep -Fxq '  FAIL  2 of 3 rows parse' \
      && ! printf '%s\n' "$out" | grep -q '^  PASS'; then
      say "  PASS  $arm fixture rejected, exit $rc"
    else
      say "  FAIL  $arm fixture escaped the board gate (exit $rc)"; fails=$((fails+1))
    fi

The arm printed `printf '%s\n' "$out"` in both branches, so a reader could reconstruct the
verdict. Two runs, byte-identical evidence, opposite verdicts:

```
  FAIL  duplicate-id fixture escaped the board gate (exit 1)     <- hook run
  FAIL  board duplicate id 'CF-001': lines 1 and 2
  FAIL  2 of 3 rows parse

  PASS  duplicate-id fixture rejected, exit 1                    <- direct run
  FAIL  board duplicate id 'CF-001': lines 1 and 2
  FAIL  2 of 3 rows parse
```

Both blocks carry `rc=1`, the expected named FAIL row, the `2 of 3 rows parse` row, and no `PASS`
row from `board_arm`. Both satisfy all three conditions. One printed FAIL.

## 2. The mechanism (v2): `pipefail` turns an early-exiting `grep -q` into a failed pipeline

The suite runs under `set -uo pipefail`. In `producer | grep -q …`, `grep -q` exits the moment it
matches and closes the pipe. If the producer still has bytes to write it dies of `SIGPIPE` (141),
and **`pipefail` promotes that to the pipeline's status** — so a pipeline whose grep DID match
reports non-zero. The suite already knows this: the landing section carries the comment "*`case`,
not `printf | grep -q`: under `set -o pipefail` an early-exiting grep can turn a match into a
failed pipeline*". Section 7b was never converted.

Which side of the pipe wins is a scheduling decision, so the verdict depends on timing rather than
on the bytes. Both directions are reachable, and both are demonstrated below **on the decider
extracted mechanically from `origin/main`, not on a paraphrase**:

| case | payload | pre-fix verdict | correct | post-fix verdict |
| --- | --- | --- | --- | --- |
| A | correct rejection + ~2 MB tail | **FAIL** | PASS | PASS |
| B | leaked a PASS row, FAIL rows after it | FAIL | FAIL | FAIL |
| C | wrong exit status (`rc=0`) | FAIL | FAIL | FAIL |
| D | `2 of 3` row only, named row absent | FAIL | FAIL | FAIL |
| F | leaked PASS row **first**, FAIL rows last, ~2 MB between | **PASS** | FAIL | FAIL |

Case A is the failure this lane actually hit: a fixture that was correctly rejected is reported as
"escaped the board gate", which reds the whole suite and, because the suite is the pre-commit hook,
refuses a commit for a diff that never touched it. Case F is the worse one, found while proving the
class: with a leaked `PASS` row early and the FAIL rows late, all three conditions read TRUE and a
board gate that leaked a PASS row is **certified**. A gate that can be wrong in both directions is
decoration.

Reproduce exactly (the script extracts both deciders from the two trees at run time):

```bash
bash docs/audits/cf482-decider-differential.sh "$PWD"
```

## 3. The fix

Section 7b now decides through one named helper, `board_fixture_verdict out rc expected`, which
prints its decision **and the three values it decided on** and returns 0/1. It uses `case` globs on
a newline-wrapped copy of the output, so there is no producer process, no pipe and no `SIGPIPE`:
the verdict is a pure function of `(rc, out)`. The loop no longer re-derives the conditions:

    if verdict=$(board_fixture_verdict "$out" "$rc" "$expected"); then
      say "  PASS  $arm fixture rejected: $verdict"
      printf '%s\n' "$out"
    else
      say "  FAIL  $arm fixture escaped the board gate: $verdict"; fails=$((fails+1))
      printf '%s\n' "$out"
    fi

All three conditions survive: `rc=1`, the fixture's own named FAIL row, the `2 of 3 rows parse`
row, and no line-start `PASS` row. Nothing was relaxed — the helper is strictly harder to satisfy
than the pipeline it replaced, because it cannot be satisfied by a scheduling accident.

## 4. Five consecutive runs, verdict beside the evidence it judged

Section 7b now also runs the duplicate-id fixture five times on unchanged inputs, printing each
verdict next to the `board_arm` output it judged. Verbatim from the green suite run at the closing
tree (`SELFTEST: PASS`, `EXIT=0`, 594 PASS rows):

```
  ..    CF-482 duplicate-id fixture, five consecutive verdicts
  PASS  CF-482 iteration 1 -> rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked
          |   FAIL  board duplicate id 'CF-001': lines 1 and 2
          |   FAIL  2 of 3 rows parse
  PASS  CF-482 iteration 2 -> rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked
          |   FAIL  board duplicate id 'CF-001': lines 1 and 2
          |   FAIL  2 of 3 rows parse
  PASS  CF-482 iteration 3 -> rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked
          |   FAIL  board duplicate id 'CF-001': lines 1 and 2
          |   FAIL  2 of 3 rows parse
  PASS  CF-482 iteration 4 -> rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked
          |   FAIL  board duplicate id 'CF-001': lines 1 and 2
          |   FAIL  2 of 3 rows parse
  PASS  CF-482 iteration 5 -> rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked
          |   FAIL  board duplicate id 'CF-001': lines 1 and 2
          |   FAIL  2 of 3 rows parse
```

Every iteration agrees with its own printed evidence, and the evidence is printed whole, so the
verdict of any future iteration can be re-derived by hand. The 200-iteration determinism check in
the differential (case E) shows both deciders stable at the suite's real ~150-byte payload, which
is why the historical divergence is **not** attributed to size alone.

## 5. What is still not proven

**The trigger of the observed third-execution divergence is not established.** The real arm's
payload is ~150 bytes, far below a pipe buffer, and the pre-fix decider did not disagree with
itself in 200 iterations at that size. What is established is narrower and sufficient: the decider
had a scheduling-dependent failure mode, it was demonstrated in both directions on a payload that
does reach it, and its verdict could not be re-derived from the evidence it printed (case A shows a
payload that satisfies all three conditions yet was judged FAIL). "It passes now" is not offered as
a mechanism — the arm is now a pure function of its inputs, and the class of race that could flip
it has been removed rather than outrun.

## 6. Residual

The same `producer | grep -q` shape appears 562 times across `tests/selftest.sh`
(`grep -cE "printf .*\| *grep (-q|-Fq|-Fxq|-F)" tests/selftest.sh`). Each site is
only at risk when its producer emits more than a pipe buffer's worth after the match, so most are
inert — but this row fixed the arm it was filed from, not the pattern. A follow-up row should sweep
the sites whose producers can emit large output (fixture transcripts, captured suite logs) and
convert them to `case` or a here-string, with the same both-directions red-proof.

## 7. Reproduce

```bash
git archive ca013e7c | tar -x -C <scratch>/src        # or any later tip
cd <checkout>
bash docs/audits/cf482-decider-differential.sh "$PWD" # cases A-F, pre vs post decider
bash tests/selftest.sh | sed -n '/^7b\./,/^8\./p'     # the five iteration blocks
```

Tier for this artifact: T3 — the deciders were executed (both trees), the suite was run green at the
closing tree, and the five iterations are quoted from that run's output.
