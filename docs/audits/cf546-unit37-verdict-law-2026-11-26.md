# CF-546 unit-37 verdict-law correction — 2026-11-26

Tick: code-factory-docs-2026-11-26-11-51-01 (docs lane).
Rows: **CF-546** (this correction) and **CF-547** (filed, not fixed here — the pre-CF-354
`text_b64` staleness in the same file).
Measured at: `e7ffed76f40cbe00b7a408fe64455c94b10463bb` (origin/main at tick start; the
canonical checkout stayed byte-clean — a sibling CF-426 worker held it, so the whole pass ran
in a detached worktree under `<scratch>` and every path below is repo-relative or `~`-relative).
Page under correction: `docs/handbook/appendices/units/37-specs-envelope-md.md` — the
field-level proof page for CF-216.

The acceptance greps in CF-546 are scoped to the unit page itself
(`docs/handbook/appendices/units/37-specs-envelope-md.md`), so this audit file can quote the
retired sentence as the before-state without breaking them; a recursive grep over `docs/`
would find the phrase here and only here, which is deliberate.

## 1. The falsified claims (before-state at e7ffed76)

`git diff --stat 3c4c639 HEAD -- specs/ENVELOPE.md` (the Revision row claimed this diff was
empty):

```
 specs/ENVELOPE.md | 227 ++++++++++++++++++++++++++++++++++++++++++++++++++++--
 1 file changed, 220 insertions(+), 7 deletions(-)
```

The page's Revision row read: ``Revision | `3c4c639` (spec unchanged since — `git diff
3c4c639 -- specs/ENVELOPE.md` is empty)`` — false by the diff above (the CF-355 §Result law,
`cae82b6b`, 2026-11-25).

Field 15's scheduler column (line 86 before the edit) taught the retired law — "Success is
the boolean `ok`, and **absence of `ok` is a success** (`~/sched-base-check/internal/scheduler/
dispatch_leg.go L442 — out-of-tree repo`). The in-repo node sends `status` and no `ok`
[scripts/node-bus-worker.py:925], so a `failed` or `refused` result from it correlates on
`corr_id` and is then read as success." — and carried wrong letters `D N`.

Field 17 carried wrong letters `S N D` (the node did not send `served_model`).

Headline and §2e counts: `23 of the 24` fields disagree, `the scheduler on 19`, `the node
disagrees with the spec on 5`.

Presence greps before the edit (each printed 1 or more): `absence of \`ok\` is a success`,
`unchanged since`, `23 of the 24`, `the scheduler on 19`, `the node disagrees with the spec
on 5`, `cannot execute a single dispatch`.

## 2. The shipped law that falsifies them (measured 2026-11-26)

In-repo, at `e7ffed76`:

- `specs/ENVELOPE.md:132` — `### \`ok\` is the verdict; \`status\` is the node's own
  classification`; `:145` — "unrecognised status — or no status at all — is **refused**.
  Absence never reads as success:".
- `scripts/node-bus-worker.py:1790` — `"status": status,`; `:1796` — `"ok": not
  failed_status,`; `:1803` — the `"harness": {` result member; `:1241` — `def
  harness_attribution(dispatch, served_model=None):` (emits `model_requested`,
  `served_model`, `served_model_source`).

Out-of-tree scheduler (`~/coding-hermes-scheduler/coding-herms-scheduler` at `15e02f99`,
read-only):

- `internal/scheduler/dispatch_leg.go` L736 — `var dispatchReplyStatuses = map[string]bool{
  "completed": true, "failed": true, "refused": true }`; L749 — `func
  dispatchReplyVerdict(payload map[string]any) (bool, string)` under the comment "silence is
  never laundered into a success".
- `internal/scheduler/dispatch_verdict_test.go` L42-47 — the mapping table: "neither ok nor
  status is refused", "status failed with NO ok is FAIL", "status completed WITHOUT ok is
  refused", "unrecognised status with NO ok is refused", "non-boolean ok with NO status is
  refused".

The in-repo consumer model pins that scheduler source case-for-case:

```
$ python3 tests/test_bus_result_delivery.py
  PASS  consumer-pin — 12 anchors still hold in dispatch_leg.go (the model matches dispatch_leg.go)
  PASS  A11  the modelled verdict mirrors the shipped CF-355 mapping table row for row
```

(`python3 -m pytest tests/test_bus_result_delivery.py -q` → `11 passed, 3 skipped in
25.50s`, rc=0, before and after the edit.)

## 3. The correction, verified per acceptance leg (after-state)

AC1 — retired literals gone from the page:

```
grep -c 'absence of `ok` is a success' docs/handbook/appendices/units/37-specs-envelope-md.md → 0
grep -c 'unchanged since' docs/handbook/appendices/units/37-specs-envelope-md.md → 0
grep -c '23 of the 24' … → 0 ; grep -c 'the scheduler on 19' … → 0
grep -c 'the node disagrees with the spec on 5' … → 0 ; grep -c 'cannot execute a single dispatch' … → 0
```

AC2 — the new field-15 row states the shipped law with resolving anchors:

```
grep -c 'dispatchReplyVerdict' docs/handbook/appendices/units/37-specs-envelope-md.md → 2
python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 37- --strict
  37-specs-envelope-md.md  VERIFIED   1 error(s) 0 warning(s)
     FAIL  locator names no file: internal/scheduler/dispatch_leg.go:742
  MASTER-DOC: FAIL   (rc=1)
```

Exactly 1 error — the §6 locator CF-541 owns (pre-existing at the baseline, same single
error before the edit; the edit added no new locator error). The out-of-tree citations the
correction added use the page's `~/<path> L<line> — out-of-tree repo` convention, which the
checker accepts.

AC3 — counts re-derived:

```
grep -c '22 of the 24' … → 1 ; grep -c 'the scheduler on 18' … → 1
grep -c 'the node disagrees with the spec on 3' … → 1
```

Field 15's wrong column now reads `—` (no side wrong); field 17's reads `S D`.

AC4 — the consumer-pin oracle stays green after the edit (§2 output, re-run post-edit:
`PASS consumer-pin — 12 anchors still hold`, `11 passed, 3 skipped`, rc=0).

Cited in-repo locators resolve (line content at the edited tree):

```
scripts/node-bus-worker.py:1241 -> def harness_attribution(dispatch, served_model=None):
scripts/node-bus-worker.py:1325 ->     if "text_b64" in dispatch:
scripts/node-bus-worker.py:1790 ->         "status": status,
scripts/node-bus-worker.py:1796 ->         "ok": not failed_status,
scripts/node-bus-worker.py:1803 ->         "harness": {
tests/test_bus_result_delivery.py:409 ->     """`dispatchReplyVerdict` (dispatch_leg.go:749) — CF-355's result-field law.
specs/ENVELOPE.md:132 -> ### `ok` is the verdict; `status` is the node's own classification
specs/ENVELOPE.md:145 -> unrecognised status — or no status at all — is **refused**. Absence never reads as success:
```

Publish-gate preflight: `grep -c '/home/kara' docs/handbook/appendices/units/37-specs-envelope-md.md`
→ 0 (the page cites `~/…` and repo-relative paths only).

## 4. CF-547 (filed, not fixed here) — the pre-CF-354 `text_b64` staleness

Three more locations in the same file still teach the node that cannot read `text_b64`
(false since CF-354, `1f1c0fe8`, 2026-11-06 — outside this tick's one-week window, so filed
rather than corrected here):

```
:89  field 7 row — "the in-repo node reads `text` only and refuses the dispatch [scripts/node-bus-worker.py:810]"
:182 section 5 bullet — "the line a scheduler-shaped dispatch produces today, because the scheduler sends `text_b64`"
:193 section 6 row — "a dispatch whose `text` is present but base64 (`text_b64`), which this node refuses with the *same* row"
```

The shipped behaviour: `scripts/node-bus-worker.py:1325` — `if "text_b64" in dispatch:`
(decodes first; a named refusal only when it does not decode), and the consumer-pin arms run
the scheduler's `text_b64` dialect against the real worker (PASS, §2). The §2e bullet that
made the same claim was corrected under CF-546; CF-547 owns the remaining three.

## 5. Provenance

Raw command transcripts (uncommitted, `<scratch>` = the tick scratch root, pruned after
24h; this file carries every output line that matters):

- before-transcript.txt  sha256 `15cc510ac1e897fa645d0f4e949f0a2f37999dc45ddd2b373cf2daf1a62d7278`
- after-transcript.txt   sha256 `c38e7ce38106de1ce56c360056d0a71535dfdf8f13cbf3464a3f9b459df4ec1d`
- cf547-evidence.txt     sha256 `28e222e86df532acf95c2ebbece61a8f1cd11820e3705b92cc70755a291e4351`

The `root:` line in the raw `master_doc_check` output names the absolute worktree path; it
is elided here as `<scratch>`. The closeout event for CF-546 (appended after the judge run)
carries the verdict binding; this artifact is frozen before the judge and its markers stay
open-finding by design. The marker-form line count in this file is 2 (one per row), verified
by grep on the final bytes.

## Markers

ch:trace row=CF-546 spec=docs/handbook/appendices/units/37-specs-envelope-md.md#2d-field-by-field-comparison--the-24-fields-the-spec-defines wave=none:docs-lane-serial test=tests/test_bus_result_delivery.py doc=docs/handbook/appendices/units/37-specs-envelope-md.md prompt=~/.hermes/skills/documentation/docs-claim-correction/SKILL.md evidence=docs/audits/cf546-unit37-verdict-law-2026-11-26.md witness=none:repo-local-comparison-captured-in-evidence-artifact verdict=none:open-finding commit=none:open memory=/project/code-factory/docs-audit-2026-11-26-11-51-01
ch:trace row=CF-547 spec=docs/handbook/appendices/units/37-specs-envelope-md.md#2d-field-by-field-comparison--the-24-fields-the-spec-defines wave=none:docs-lane-serial test=tests/test_bus_result_delivery.py doc=docs/handbook/appendices/units/37-specs-envelope-md.md prompt=~/.hermes/skills/documentation/docs-claim-correction/SKILL.md evidence=docs/audits/cf546-unit37-verdict-law-2026-11-26.md witness=none:repo-local-comparison-captured-in-evidence-artifact verdict=none:open-finding commit=none:open memory=/project/code-factory/docs-audit-2026-11-26-11-51-01
