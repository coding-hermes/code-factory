# CF-481 — an arm that refuses a returning traceability block in `README.md`

Row: `CF-481` (P3). Tick: `code-factory-readme-2026-11-17-02-40-53`, fourth execution.
Base: published tip `40520c6f6f1b46687b4bd1b0046e320fdb0fec13`.

## Why the arm exists

`CF-480` removed a block of seven `ch:trace` marker lines plus `STATUS:` / `TIER:` /
`EVIDENCE:` lines that ended `README.md`, whose own `evidence=` was `README.md`. The suite already
checks README **content** (prompt references in section 9, the census mirror, `HERMES_PYTHON_BIN`,
`BUNKER_SERVER`) but nothing refused a trace block: the block shipped for weeks and was found by a
lane reading the file by hand. This arm makes that regression red.

## The checker (one implementation, both directions)

`tests/selftest.sh`, block `# BEGIN cf481-readme-trace-guard` … `# END cf481-readme-trace-guard`:

```bash
readme_trace_block() {  # $1=README -> prints each offending line, returns 1 if a trace block is present
  local readme="$1" hits
  hits=$(grep -nE '^(ch:trace|STATUS:|TIER:|EVIDENCE:)' "$readme" 2>/dev/null)
  [ -z "$hits" ] && return 0
  printf '%s\n' "$hits"
  return 1
}
```

It is anchored to line starts on purpose: the old block began each line at column 0, while prose may
mention the same words mid-sentence. Arm (c) is the control for that anchoring.

## Direction 1 — the published tree passes

    $ bash docs/audits/cf481-readme-trace-guard-probe.sh   # extracted block, run against this checkout
    76. README carries no traceability block (CF-481)
      PASS  published README.md carries no ch:trace / STATUS: / TIER: / EVIDENCE: line
      PASS  a. red control: a planted ch:trace line is rejected, exit 1
      PASS  b. red control: a planted STATUS: line is rejected, exit 1
      PASS  b. red control: a planted TIER: line is rejected, exit 1
      PASS  b. red control: a planted EVIDENCE: line is rejected, exit 1
      PASS  c. a mid-sentence mention is accepted (the check is anchored to line starts)
    FAILS=0

## Direction 2 — a README carrying one marker line goes red (the red control)

The same block run against a temp root whose `README.md` is the published file plus one appended
`ch:trace` line (second half of `bash docs/audits/cf481-readme-trace-guard-probe.sh`):

    76. README carries no traceability block (CF-481)
      FAIL  published README.md carries a traceability block again:
        | 353:ch:trace row=CF-999 spec=none test=none doc=README.md
      PASS  a. red control: a planted ch:trace line is rejected, exit 1
      PASS  b. red control: a planted STATUS: line is rejected, exit 1
      PASS  b. red control: a planted TIER: line is rejected, exit 1
      PASS  b. red control: a planted EVIDENCE: line is rejected, exit 1
      PASS  c. a mid-sentence mention is accepted (the check is anchored to line starts)
    FAILS=1

Census of the published file at the same moment: `grep -cE '^(ch:trace|STATUS:|TIER:|EVIDENCE:)' README.md` → `0`.

Each arm varies one input. The planted fixtures are copies of the published `README.md` with exactly one
line appended; arm (c) uses a self-contained two-line fixture so it cannot inherit arm (a)'s state — the
first draft copied the live README and reported two FAIL rows for one cause, which is why it was rewritten.

## What this does NOT cover

- A marker line **indented** by leading whitespace is not caught, because the regex is anchored at column
  0. The block this row is about began every line at column 0; an indented variant would need the anchor
  widened, and that would also catch fenced examples, so it is a deliberate residual rather than an
  oversight.
- The arm reads the track's own `README.md` only. A marker block in another published document (for
  example a `docs/` page) is out of scope for this row.

## Where the trace marker lives

One marker for this row is authored on the board row's `foreman_note` at close-out, after this artifact
is published, because `commit=` and `witness=path@origin:` cannot be written into a file that has not
shipped yet. This artifact deliberately carries no second marker: two markers for one row is the
duplication the census rule counts once and cannot arbitrate.

## The plan census re-pin (a numbered section cannot land alone)

Adding section 76 moved the tree's arm count, and `docs/ACCEPTANCE-PLAN.md` grades that number from
two instruments. Measured both sides at this tree:

    before the re-pin
      bash docs/audits/cf198-section-mapping.sh     -> MISSING §76 … arms_plan=75 arms_tree=76 -> RESULT: DRIFT (2)
      bash docs/audits/cf099-prd-drift-probe.sh --sections-only
                                                    -> DRIFT: plan says 71 sections, tests/selftest.sh has 72
    after the re-pin (Current state line, §76 mapping row, and the reverse-direction list at 39 unnamed / 24 governed)
      bash docs/audits/cf198-section-mapping.sh     -> OK §76 — plan row present; arms_plan=76 arms_tree=76; RESULT: OK
      bash docs/audits/cf099-prd-drift-probe.sh --sections-only
                                                    -> plan_sections=72 selftest_sections=72, CF099_RC=0

The first full-suite attempt in this tick failed on exactly this (`FAIL section-mapping-real — expected
RESULT: OK with arms_plan == arms_tree (exit 1): arms_plan=75 arms_tree=76`) and on nothing else: the new
block's six rows were PASS in that same run. So the census, not the arm, was the red.

## Suite

    $ bash tests/selftest.sh
    …
    76. README carries no traceability block (CF-481)
      PASS  published README.md carries no ch:trace / STATUS: / TIER: / EVIDENCE: line
      PASS  a. red control: a planted ch:trace line is rejected, exit 1
      PASS  b. red control: a planted STATUS: line is rejected, exit 1
      PASS  b. red control: a planted TIER: line is rejected, exit 1
      PASS  b. red control: a planted EVIDENCE: line is rejected, exit 1
      PASS  c. a mid-sentence mention is accepted (the check is anchored to line starts)

    SELFTEST: PASS
    EXIT=0
    SUITE2_RC=0

589 `PASS` rows in that run. Suite sentinel and every row above were captured from the run itself, not
retyped; the run happened at this tree, whose `git rev-parse HEAD` is the commit that carries this file's
parent state plus this change.
