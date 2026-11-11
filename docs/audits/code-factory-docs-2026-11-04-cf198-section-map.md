# code-factory docs lane — tick `code-factory-docs-2026-11-04-10-01-07` (claim: the section-mapping table)

Second execution of this tick id. The first execution of `2026-11-04-1001` took a different claim
(`CF-197`, the public-bind auth gate prose) and landed it; its evidence file is
`docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md` and it is left unclaimed and
unmodified here. This file covers a distinct claim and a distinct board row (`CF-198`).

## Claim corrected

`docs/ACCEPTANCE-PLAN.md` promised that its "test sections with no PRD requirement" mapping table
names **every** numbered section in the tree. The `CF-182` landing (`b626238`, 2026-11-04) added
§38 to `tests/selftest.sh` and left the table at §37, so the promise was false at the published tip
`a564cda`, and the prose count on the same page contradicted the count line above it (38 sections
at line 5, 37 at line 104).

| Where | Before | After |
|---|---|---|
| `docs/ACCEPTANCE-PLAN.md:104` | "names every numbered section in the current tree — 37, plus three lettered arms (§4b, §7b, §31b), so 40 arms" | "— 38, plus three lettered arms (§4b, §7b, §31b), so 41 arms" |
| `docs/ACCEPTANCE-PLAN.md:105` | "the tree therefore carries 40 arms without it and 41 once it lands" | "carries 41 arms without it and 42 once it lands" |
| `docs/ACCEPTANCE-PLAN.md:144` | (no row) — table ended at §37 | new row `§38 the milestone blocker list resolves every cited id in one namespace` → board `CF-182` |

## The code path that proves the new statement

- `tests/selftest.sh:1866` — `say "38. the milestone blocker list resolves every cited id in one namespace (CF-182)"`;
  the arm runs `docs/audits/prd-blocker-resolution.sh` and asserts three independent failures
  (real PRD green, unresolved `CF-999` red, cited-but-complete row red).
- `docs/audits/prd-blocker-resolution.sh` — decides each `CF-nnn` cited between the
  `milestone-blockers` markers as `row=<status>` (board) or `requirement-only` (PRD requirements
  table); exits 1 on an unresolved id, a cited row already complete, or a requirement-only row with
  no `Verified by` cell.
- `b626238` "gate(prd): resolve every milestone blocker id in one namespace (CF-182)" — the commit
  that added the section the table did not name (`git cat-file -t b626238` = `commit`).

## Literal commands and output

Probe (extracted verbatim from board row `CF-198.probe`, `bash -n` clean, run from the repo root):

```
$ bash cf198-probe.sh            # pre-fix tree, detached worktree at a564cda
selftest_sections=38
plan_says=38
mapping_last=37
DRIFT: selftest has 38 sections, plan claims 38, mapping table ends at section 37

$ bash cf198-probe.sh            # fixed tree
selftest_sections=38
plan_says=38
mapping_last=38
OK pins agree
```

Counts on the fixed tree:

```
$ grep -cE '^say "[0-9]+\."' tests/selftest.sh           -> 38
$ grep -cE '^say "[0-9]+[a-z]\.' tests/selftest.sh        -> 3   (§4b, §7b, §31b)
$ grep -oE '^\| §[0-9]+' docs/ACCEPTANCE-PLAN.md | ... tail -1 -> 38
```

Gate (CI-equivalent; this repo ships no GitHub Actions — `gh run list` returns `[]`):

```
$ bash tests/selftest.sh
...
38. the milestone blocker list resolves every cited id in one namespace (CF-182)
  PASS  prd-blocker — 14 cited ids, 12 rows, 2 requirement-only, exit 0
  PASS  prd-blocker-red — CF-999 unresolved, exit 1
  PASS  prd-blocker-closed — CF-009 complete, exit 1

SELFTEST: PASS
rc=0, 193 PASS rows, 50 FAIL rows (every FAIL row is an intentional negative fixture)
```

Both arms ran in a throwaway clone of the published ref (`gh/main`), not in the registered
checkout `~/code-factory`, which a sibling `gitreins task complete
CF-SYNC-20261104-0958-A1` (pid 3996532) was writing during this tick. The pre-fix arm ran in a
`git worktree add --detach` of that clone at `a564cda`, so the RED is reproducible without touching
the shared tree.

## Claims I could not verify

- Whether the mapping table names every arm **mechanically**: not measured. The census script
  `docs/audits/cf099-prd-drift-probe.sh` counts only numbered `say` lines and the table merges
  ranges onto one row (§22–§28, §4/§4b), so table-row count (34) ≠ section count (38) by design.
  Nothing enforces the promise; `CF-113` (pending) owns counting lettered arms.
- §7c restoration (`CF-186`, pending): the tree still carries 41 arms, not 42 — not measured beyond
  `grep -c cf155 tests/selftest.sh` = 0.
- Line 5's full count sentence (171 rows / 343 events at `aead5f5`) was **not** re-measured by this
  tick; the board has moved since. The section/arm counts on that line (38 / 41) are the only
  numbers this tick confirms, and it confirms them at `a564cda`, not at `aead5f5`.

ch:trace row=CF-198 spec=docs/ACCEPTANCE-PLAN.md test=tests/selftest.sh#38 evidence=docs/audits/code-factory-docs-2026-11-04-cf198-section-map.md verdict=CF-198-DOC1 commit=HEAD
STATUS: done
TIER: T3
EVIDENCE: pre-fix DRIFT at a564cda vs post-fix "OK pins agree"; `bash tests/selftest.sh` PASS rc=0
