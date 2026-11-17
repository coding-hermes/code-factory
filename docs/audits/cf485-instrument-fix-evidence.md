# CF-485 — the CF-482 instruments fail closed

Row: `CF-485` (P3). Tick: `code-factory-readme-2026-11-17-02-40-53`, fifth execution.
Base: published tip `b9a6ea60a13f2607fdcc82090246e23483c6d73b`, worked in a scratch worktree of this
repository. Every transcript below was captured from a run at this tree; absolute host paths are
written as `$HOME`.

The row exists because the artifact that "proves" the CF-482 fix could report a reproduction it
never measured. Three of the judge's findings survived re-execution, and this change closes them
plus the uncovered failure path the verdict named (nothing red-ed if the producer-piped shape
returned to §7b).

## Before — the differential at the tip

Run from the published script (`git show b9a6ea60:docs/audits/cf482-decider-differential.sh`),
against this checkout:

```
$ bash docs/audits/cf482-decider-differential.sh .        # the script as published at b9a6ea60
=== extracted pre-fix condition ===
  | [ "$rc" -eq 1 ] && [ "$(cat "$tmpd/launch" 2>/dev/null)" = 'serve launch reached' ] \
  |     && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]
=== extracted post-fix condition ===
  | verdict=$(board_fixture_verdict "$out" "$rc" "$expected")
=== helper lines: 21 ===

--- case A: a correct rejection (matching payload, ~2000000B tail) ---
cf485-old-differential.sh: line 35: tmpd: unbound variable
  pre  -> FAIL   (correct answer: PASS)
  post -> PASS   (correct answer: PASS)

--- case B: a fixture that LEAKED a PASS row (must be refused) ---
cf485-old-differential.sh: line 35: tmpd: unbound variable
  pre  -> FAIL   (correct answer: FAIL)
  post -> FAIL   (correct answer: FAIL)

--- case C: wrong exit status ---
  pre  -> FAIL   (correct answer: FAIL)
  post -> FAIL   (correct answer: FAIL)

--- case D: right-looking output, missing the named FAIL row ---
cf485-old-differential.sh: line 35: tmpd: unbound variable
  pre  -> FAIL   (correct answer: FAIL)
  post -> FAIL   (correct answer: FAIL)
```

Two things are wrong on the first screen alone:

* The "pre-fix condition" is `[ "$(cat "$tmpd/launch" ...)" = 'serve launch reached' ]` — the
  **serve-launch arm of another section**, not §7b's board-gate decider. `origin/main:tests/selftest.sh`
  already carries the CF-482 helper, and the anchor `^  if [ "$rc" -eq 1 ]` occurs 60 times in the
  tip's selftest, so the first match is unrelated.
* `$tmpd` is the suite's scratch root and does not exist in the differential's scope, so the pre
  decider aborts instead of deciding.

204 of the transcript's 236 lines are that abort (one per case-E iteration); the tail:

```
--- case E: the small payload the suite really produces, 200 iterations each ---
  pre  disagreed with itself 200/200   (0 = deterministic at this size)
  post disagreed with itself 0/200  (0 = deterministic at this size)

--- case F: a leaked PASS row FIRST, the two FAIL rows last, ~2MB between them ---
  pre  -> FAIL   (correct answer: FAIL)
  post -> FAIL   (correct answer: FAIL)
exit=0
```

It exits 0, prints `(correct answer: …)` beside rows it never decided, and never refuses. Run at the
tip through a pipe (`| head -60`) the same script surfaced `EXIT=141` from the closed pipe — the
failure was visible only because a downstream reader stopped reading.

The script also only ever graded the post decider's **exit status**: `decide_post` printed
`PASS`/`FAIL` from `if eval`, so a helper that returned 0 while printing a FAIL reason would have
been recorded as a pass.

## After — every case decided, the planted helper caught

```
$ bash docs/audits/cf482-decider-differential.sh .
=== extracted pre-fix condition (ca013e7c54fd0b284b3a40ca77e28693192669da section 7b: 74 lines) ===
  | [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "  FAIL  $expected" \
  |     && printf '%s\n' "$out" | grep -Fxq '  FAIL  2 of 3 rows parse' \
  |     && ! printf '%s\n' "$out" | grep -q '^  PASS'
=== extracted post-fix condition ===
  | verdict=$(board_fixture_verdict "$out" "$rc" "$expected")
=== helper lines: 21 ===
=== preflight: pre-fix condition runs under set -u (probe_ok=1) ===

--- case A: a correct rejection (matching payload, ~2000000B tail) ---
  pre -> status=141 decision=FAIL printed=''  probe_ok=1  (correct answer: PASS)  grader=CLEAN
  post -> status=0 decision=PASS printed='rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked'  probe_ok=1  (correct answer: PASS)  grader=CLEAN

--- case B: a fixture that LEAKED a PASS row (must be refused) ---
  pre -> status=141 decision=FAIL printed=''  probe_ok=1  (correct answer: FAIL)  grader=CLEAN
  post -> status=1 decision=FAIL printed='rc=1; board_arm leaked a PASS row'  probe_ok=1  (correct answer: FAIL)  grader=CLEAN

--- case C: wrong exit status ---
  pre -> status=1 decision=FAIL printed=''  probe_ok=1  (correct answer: FAIL)  grader=CLEAN
  post -> status=1 decision=FAIL printed='rc=0; exit 0, expected 1'  probe_ok=1  (correct answer: FAIL)  grader=CLEAN

--- case D: right-looking output, missing the named FAIL row ---
  pre -> status=1 decision=FAIL printed=''  probe_ok=1  (correct answer: FAIL)  grader=CLEAN
  post -> status=1 decision=FAIL printed='rc=1; named FAIL row (  FAIL  board duplicate id 'CF-001': lines 1 and 2) absent'  probe_ok=1  (correct answer: FAIL)  grader=CLEAN

--- case E: the small payload the suite really produces, 200 iterations each ---
  pre  PASS 200/200, disagreed with itself 0/200   (0 = deterministic at this size)
  post PASS 200/200, disagreed with itself 0/200  (200 = deterministic at this size)

--- case F: a leaked PASS row FIRST, the two FAIL rows last, ~2MB between them ---
  pre -> status=0 decision=PASS printed=''  probe_ok=1  (correct answer: FAIL)  grader=CLEAN
  post -> status=1 decision=FAIL printed='rc=1; board_arm leaked a PASS row'  probe_ok=1  (correct answer: FAIL)  grader=CLEAN

--- case G: planted helper — prints a FAIL reason, returns 0 ---
  planted -> status=0 decision=PASS printed='rc=1; named FAIL row absent'  probe_ok=1  (correct answer: FAIL)  grader=DEFECT (helper printed a FAIL reason with exit 0)

--- real helper, graded on its printed verdict ---
  post printed 'rc=1; named FAIL row present; 2-of-3 row present; no PASS row leaked' (exit 0) -> grader=CLEAN

cases decided: 11; planted helper caught: yes; post disagreements: 0; failed rows: 0
RESULT: OK (every case decided, the planted helper was caught, the real helper graded clean)
```

The pre decider is now §7b's own three-pipeline condition, and the run shows the two failure
directions the differential exists to name: case A fails a **correct** rejection (`status=141`, the
`! printf | grep -q` clause taking SIGPIPE under `pipefail`) and case F certifies a fixture that
**leaked** a PASS row (`decision=PASS` where the correct answer is FAIL). The post decider decides
all six cases and agrees with the correct answer in every one.

## AC1 — the differential refuses instead of guessing

The pre blob comes from `$pre_ref` (default `ca013e7c`, the parent of the CF-482 fix `f3a61ff7`);
the condition is extracted from inside the §7b block only, validated, and preflighted. Three
refusals were proved by running the shipped script, each exit **2**:

```
$ bash docs/audits/cf482-decider-differential.sh .        # a scratch git repo with no such ref
REFUSED: cannot read the pre-fix blob 'ca013e7c54fd0b284b3a40ca77e28693192669da:tests/selftest.sh' — ref 'ca013e7c54fd0b284b3a40ca77e28693192669da' is unresolved here; git said: fatal: path 'tests/selftest.sh' does not exist in 'ca013e7c54fd0b284b3a40ca77e28693192669da'
exit=2
```

```
$ PRE_REF=<a pre-fix commit with no section 7b> bash docs/audits/cf482-decider-differential.sh "$PWD"
REFUSED: the section 7b block of '3deb7e3b2a2c4143effca218d60778e4b5841f44:tests/selftest.sh' carries no ^  if [ "$rc" -eq 1 ] decider (rc=3)
exit=2
```

```
$ PRE_REF=<a pre-fix commit whose 7b decider references an unset suite variable> bash docs/audits/cf482-decider-differential.sh "$PWD"
=== helper lines: 21 ===
REFUSED: the extracted pre-fix condition cannot run in this scope: $HOME/.hermes/cache/scratch/cf485-wt-055419/docs/audits/cf482-decider-differential.sh: line 124: undefined_suite_var: unbound variable
exit=2
```

The second refusal is the empty-condition case: nothing matched inside §7b, so nothing is
evaluated — `eval ''` never runs. The third is the third root cause: a fragment that aborts under
`set -u` is refused at preflight (its probe payload satisfies the row assertions so evaluation
reaches every term), and the same condition is re-checked per case (`probe_ok=`/`dec_err` in the
output above), so an abort can never be reported as a decider verdict. No `set -e` was added: the
existing cases rely on non-zero statuses being read, so the script uses a per-case `probe_ok=1`
plus explicit `refuse()` exits, and it exits 1 with `RESULT: DEFECT` if any instrument-side
assertion fails.

## AC2 — the helper's printed verdict is graded, not only its exit status

Both deciders now report the helper's own printed text beside its status (`status=… decision=…
printed='…'`), and `grade_decider` treats these as defects:

* helper exits 0 while printing a defect phrase (`absent`, `leaked`, `exit `), or
* helper exits non-zero while printing the success sentence
  `named FAIL row present; 2-of-3 row present; no PASS row leaked` (quoted verbatim, so the bare
  word `leaked` inside the success sentence is not mistaken for the FAIL reason).

Case G proves the grader fires: a planted `board_fixture_verdict` that prints
`rc=1; named FAIL row absent` and `return 0` is reported as
`DEFECT (helper printed a FAIL reason with exit 0)`. The real helper, graded through the same
function on the same payload, is `CLEAN`.

## AC3 — two payload orderings

```
$ bash docs/audits/cf482-pipefail-probe-direction2.sh
iterations per ordering: 20

=== ORDERING 1 — a PASS row IS present, on line 1 ===
  payload_bytes=2000023; a '  PASS' row IS present on line 1
  RESULTS over 20 iterations:
  shipped shape (! printf|grep -q '^  PASS') reported 'no PASS row' = 20/20  (correct answer: 0)
  case glob  reported 'no PASS row' = 0/20  (correct answer: 0)
  side by side: grep-shape -> 'no PASS row' (20/20) | case-shape -> 'a PASS row is present' (0/20) | correct: 'no PASS row' on exactly 0 of 20
  verdict: grep shape is WRONG here (20/20 vs correct 0/20)

=== ORDERING 2 — no PASS row anywhere ===
  payload_bytes=2000077; no '  PASS' row is present
  RESULTS over 20 iterations:
  shipped shape (! printf|grep -q '^  PASS') reported 'no PASS row' = 20/20  (correct answer: 20)
  case glob  reported 'no PASS row' = 20/20  (correct answer: 20)
  side by side: grep-shape -> 'no PASS row' (20/20) | case-shape -> 'no PASS row' (20/20) | correct: 'no PASS row' on exactly 20 of 20
  verdict: grep shape agrees with the correct answer here

RESULT: OK (both orderings measured; the case shape matched the correct answer in both)
```

Ordering 2 is the one the old probe never ran: with no PASS row anywhere the correct answer is
"no PASS row" for **both** shapes, so a shape that is wrong in the opposite direction (a false
rejection) can no longer hide behind ordering 1's result. The iteration count (`TRIES=20`) and the
two shipped labels are unchanged.

## AC4 — section 77 reds if the shape returns to §7b

New numbered section **§77** (`tests/selftest.sh`, block
`# BEGIN cf485-7b-pipe-grep-guard` … `# END cf485-7b-pipe-grep-guard`). `cf485_7b_pipe_grep` extracts
the §7b block — from the `say "7b.` line to the line before the next `^say "` at column 0, the same
boundary AC1's differential uses — and names every line matching
`| grep -q` / `| grep -Fq` / `| grep -Fxq`. The scanner reads with `awk`, not a `printf | grep -q`
pipeline of its own, so the checker cannot exhibit the shape it rejects.

Both arms in the full suite run:

```
77. section 7b never pipes a producer into grep -q (CF-485)
  PASS  a. shipped tests/selftest.sh section 7b scans clean — block 28 lines, 0 offending
  PASS  b. red control: the planted producer-piped grep -q is the one offending line — line 587:   if printf '%s\n' "$out" | grep -q '^  PASS'; then leaked=1; fi
```

The planted line is `  if printf '%s\n' "$out" | grep -q '^  PASS'; then leaked=1; fi`, inserted
after the `say "7b.` line of a copy of the shipped suite; the scanner must report exactly one
offending line and name that text. Both conditions are asserted (`offending == 1` **and** the hit
names the planted text), so a scanner that reported "one line" for the wrong reason still reds.

The red control this row really exists for is the pre-fix tree: the same scanner run over
`ca013e7c:tests/selftest.sh` (the blob AC1 extracts from) reports five offender lines — the
three-pipeline decider CF-482 replaced plus the two it left in the unterminated-tail arm:

```
77. section 7b never pipes a producer into grep -q (CF-485)
  FAIL  a. shipped tests/selftest.sh section 7b feeds a producer into grep -q (block 74 lines, 5 offending, exit 0)
    | line 559:   if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "  FAIL  $expected" \
    | line 560:     && printf '%s\n' "$out" | grep -Fxq '  FAIL  2 of 3 rows parse' \
    | line 561:     && ! printf '%s\n' "$out" | grep -q '^  PASS'; then
    | line 598:       if printf '%s\n' "$out" | grep -Fxq '  FAIL  board: 1 unterminated row (line 2)' \
    | line 599:         && printf '%s\n' "$out" | grep -Fxq '  note  pre-fix parser control would accept 1 of 2 rows'; then
  FAIL  b. red control: the planted producer-piped grep -q was not reported as exactly one offending line (offending 6, exit 0)
    | BLOCK 75 OFFENDING 6
    | line 542:   if printf '%s\n' "$out" | grep -q '^  PASS'; then leaked=1; fi
```

(Arm (a) fails there by design — that tree is the control — which is why the run above is not a
suite result but a standalone call of the same function against the pre-fix blob.)

Scope note: the literal `^say "` boundary ends the block at the nested progress line
`say "  ..    CF-482 …`, so §7b's later unterminated-tail arm sits **outside** the scanned range.
That arm compares exact output with producer-piped `grep -Fxq` deliberately; extending the boundary
would red on a shipped, intended shape. The boundary is stated in both places (the §77 comment and
the differential's `extract_7b`) so the next reader does not "fix" it into a false red.

The suite sentinel for the run those two rows came from:

```
SELFTEST: PASS
EXIT=0
```

## Census re-pin (`docs/ACCEPTANCE-PLAN.md`)

Same commit, because a missing pin reds §39 and both instruments:

* `**Current state**`: `carries 72 numbered sections` → `73`, `the current tree carries 76 arms` → `77`.
* one mapping row added: `| §77 section 7b never feeds a producer into `grep -q` | board `CF-485` (…) |`.
* "The other direction": `(76 arms: 72 numbered sections and four lettered arms …)` →
  `(77 arms: 73 numbered sections …)`.
* "Sections with no requirement": `The remaining 39` → `40`, `§77` added to the id list,
  `24 of the 39` → `25 of the 40` with `§77 `CF-485`` in the governed list, `The other 15 of the 39`
  → `The other 15 of the 40` (40 − 25 = 15).

```
$ bash docs/audits/cf198-section-mapping.sh
OK §1 — plan row present
OK §2 — plan row present
…                                   one OK §N row per section, 77 of them
OK §76 — plan row present
OK §77 — plan row present
arms_plan=77 arms_tree=77
RESULT: OK
exit=0

$ bash docs/audits/cf099-prd-drift-probe.sh --sections-only
measured: plan_sections=73 selftest_sections=73 plan=docs/ACCEPTANCE-PLAN.md selftest=tests/selftest.sh
exit=0
```

## Gates

```
$ bash -n docs/audits/cf482-decider-differential.sh && bash -n docs/audits/cf482-pipefail-probe-direction2.sh \
    && bash -n tests/selftest.sh && echo OK
OK
$ bash docs/audits/cf482-decider-differential.sh .            -> RESULT: OK, exit 0
$ bash docs/audits/cf482-pipefail-probe-direction2.sh         -> RESULT: OK, exit 0
$ bash docs/audits/cf198-section-mapping.sh                   -> RESULT: OK, exit 0
$ bash docs/audits/cf099-prd-drift-probe.sh --sections-only   -> measured: plan_sections=73 selftest_sections=73, exit 0
$ bash tests/selftest.sh                                      -> SELFTEST: PASS, EXIT=0 (596 PASS rows, all 77 headings ran)
```

The suite was run once, in the background, with its output teed to a log; all 77 section headings
appear in that log and no arm other than §77's was touched by this change.

## Artifact digest

`sha256` of this file's body (everything before this section, so the digest is reproducible):

```
e077a9ea5675c92fcd64be877eeb145f9119982ff85199dc6691fac56b766015  docs/audits/cf485-instrument-fix-evidence.md
```

Reproduce with:

```bash
sed '/^## Artifact digest/,$d' docs/audits/cf485-instrument-fix-evidence.md | sha256sum
```
